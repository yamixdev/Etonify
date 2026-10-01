import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meow_client/widgets/release_image_loader.dart';
import 'package:meow_client/widgets/release_notes_images.dart';

final pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
final imageUri = Uri.parse(
  'https://github.com/user-attachments/assets/example',
);

void main() {
  test('encoded cache evicts least recently used entries', () async {
    var calls = 0;
    final loader = ReleaseImageLoader(
      clientFactory: () => MockClient((_) async {
        calls++;
        return http.Response.bytes(pixel, 200);
      }),
    );
    Uri entry(int index) =>
        imageUri.replace(path: '/user-attachments/assets/$index');
    for (var i = 0; i < 8; i++) {
      await loader.load(entry(i));
    }
    await loader.load(entry(0));
    await loader.load(entry(8));
    await loader.load(entry(0));
    expect(calls, 9);
    await loader.load(entry(1));
    expect(calls, 10);
  });
  test('streamed overflow is stopped even without Content-Length', () async {
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () => cancelled = true,
    );
    final loader = ReleaseImageLoader(
      clientFactory: () => MockClient.streaming(
        (_, _) async => http.StreamedResponse(stream.stream, 200),
      ),
    );
    final result = loader.load(imageUri);
    final rejected = expectLater(result, throwsFormatException);
    stream.add(List.filled(ReleaseImageLoader.maxBytes + 1, 0));
    await rejected;
    expect(cancelled, isTrue);
    await stream.close();
  });
  test(
    'simultaneous requests coalesce and eviction forces a new fetch',
    () async {
      var calls = 0;
      final ready = Completer<void>();
      final loader = ReleaseImageLoader(
        clientFactory: () => MockClient((_) async {
          calls++;
          await ready.future;
          return http.Response.bytes(
            pixel,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      final first = loader.load(imageUri);
      final second = loader.load(imageUri);
      ready.complete();
      expect(await second, same(await first));
      expect(calls, 1);
      loader.evict(imageUri);
      await loader.load(imageUri);
      expect(calls, 2);
    },
  );
  test('img attributes are parsed outside other quoted attributes', () {
    final notes = normalizeReleaseNotesImages(
      '<img data-src="$imageUri" alt="example src=invalid" src="$imageUri" />',
    );
    expect(
      notes,
      contains('](https://github.com/user-attachments/assets/example)'),
    );
    expect(
      normalizeReleaseNotesImages('<img data-src="$imageUri" />').trim(),
      '[image]',
    );
  });
  test(
    'a truncated raster is never admitted into the successful cache',
    () async {
      final loader = ReleaseImageLoader(
        clientFactory: () => MockClient(
          (_) async => http.Response.bytes(
            pixel.sublist(0, 41),
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
      await expectLater(loader.load(imageUri), throwsA(isA<Exception>()));
    },
  );
  test('GitHub img becomes a separate image block, code remains literal', () {
    const tag =
        '<img width="640" alt="photo" src="https://github.com/user-attachments/assets/example" />';
    final notes = normalizeReleaseNotesImages(
      'Last item $tag\n\n`$tag`\n\n```html\n$tag\n```',
    );
    expect(
      notes,
      startsWith(
        'Last item \n\n![photo](https://github.com/user-attachments/assets/example)\n\n',
      ),
    );
    expect(notes, contains('`$tag`'));
    expect(notes, contains('```html\n$tag\n```'));
  });
  test(
    'only trusted HTTPS image sources, never local addresses or credentials',
    () {
      for (final value in [
        'http://github.com/user-attachments/assets/x',
        'https://127.0.0.1/x',
        'https://example.com/x',
        'https://github.com.evil.com/x',
        'https://user@github.com/user-attachments/assets/x',
        'https://github.com:444/user-attachments/assets/x',
        'file:///tmp/x',
        'https://github.com/yamixdev/Etonify',
      ]) {
        expect(
          isTrustedReleaseImageUri(Uri.parse(value)),
          isFalse,
          reason: value,
        );
      }
      expect(isTrustedReleaseImageUri(imageUri), isTrue);
    },
  );
  test(
    'loads bounded image bytes, follows a trusted redirect and caches',
    () async {
      var calls = 0;
      final loader = ReleaseImageLoader(
        clientFactory: () => MockClient((request) async {
          calls++;
          if (request.url.host == 'github.com') {
            return http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://github-production-user-asset-6210df.s3.amazonaws.com/image.png',
              },
            );
          }
          return http.Response.bytes(
            pixel,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      final image = await loader.load(imageUri);
      expect(image.width, 1);
      expect(image.height, 1);
      expect(image.bytes, pixel);
      expect(await loader.load(imageUri), same(image));
      expect(calls, 2);
    },
  );
  test(
    'blocked redirects are not requested, failures can be retried',
    () async {
      var calls = 0;
      final loader = ReleaseImageLoader(
        clientFactory: () => MockClient((request) async {
          calls++;
          return http.Response(
            '',
            302,
            headers: {'location': 'http://127.0.0.1/private'},
          );
        }),
      );
      await expectLater(loader.load(imageUri), throwsFormatException);
      await expectLater(loader.load(imageUri), throwsFormatException);
      expect(calls, 2);
    },
  );
  test('rejects oversized bodies and non-raster content', () async {
    for (final response in [
      http.Response.bytes(List.filled(ReleaseImageLoader.maxBytes + 1, 0), 200),
      http.Response(
        '<svg onload="alert(1)"/>',
        200,
        headers: {'content-type': 'image/svg+xml'},
      ),
      http.Response('<html>not an image</html>', 200),
    ]) {
      final loader = ReleaseImageLoader(
        clientFactory: () => MockClient((_) async => response),
      );
      await expectLater(loader.load(imageUri), throwsFormatException);
    }
  });
}
