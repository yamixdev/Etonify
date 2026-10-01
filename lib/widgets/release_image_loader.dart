import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// Release notes are remote content, not arbitrary HTML or a web browser.
bool isTrustedReleaseImageUri(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.hasFragment) {
    return false;
  }
  return switch (uri.host) {
    'github.com' => uri.path.startsWith('/user-attachments/assets/'),
    'user-images.githubusercontent.com' ||
    'private-user-images.githubusercontent.com' ||
    'github-production-user-asset-6210df.s3.amazonaws.com' => true,
    _ => false,
  };
}

class ReleaseImageData {
  const ReleaseImageData(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;

  ImageProvider provider({int maxDimension = 960}) {
    final scale = math.min(1.0, maxDimension / math.max(width, height));
    return ResizeImage.resizeIfNeeded(
      scale < 1 ? math.max(1, (width * scale).round()) : null,
      scale < 1 ? math.max(1, (height * scale).round()) : null,
      MemoryImage(bytes),
    );
  }
}

/// Bounded, coalesced memory cache; redirects are validated before any request.
/// No cookies, credentials, disk files or HTML rendering are involved.
class ReleaseImageLoader {
  ReleaseImageLoader({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;
  static final shared = ReleaseImageLoader();
  static const maxBytes = 4 * 1024 * 1024;
  static const _cacheBytesLimit = 12 * 1024 * 1024;
  final http.Client Function() _clientFactory;
  final _cache = <Uri, ReleaseImageData>{};
  final _pending = <Uri, Future<ReleaseImageData>>{};
  int _cacheBytes = 0;

  void evict(Uri uri) {
    _cacheBytes -= _cache.remove(uri)?.bytes.length ?? 0;
  }

  Future<ReleaseImageData> load(Uri uri) async {
    if (!isTrustedReleaseImageUri(uri)) {
      throw const FormatException('Untrusted release image');
    }
    final cached = _cache.remove(uri);
    if (cached != null) {
      _cache[uri] = cached;
      return cached;
    }
    final pending = _pending[uri];
    if (pending != null) return pending;
    if (_pending.length >= 4) {
      throw const FormatException('Too many concurrent release images');
    }
    final client = _clientFactory();
    final future = _fetch(client, uri).timeout(const Duration(seconds: 12));
    _pending[uri] = future;
    try {
      final image = await future;
      while (_cache.isNotEmpty &&
          (_cache.length >= 8 ||
              _cacheBytes + image.bytes.length > _cacheBytesLimit)) {
        _cacheBytes -= _cache.remove(_cache.keys.first)!.bytes.length;
      }
      _cache[uri] = image;
      _cacheBytes += image.bytes.length;
      return image;
    } finally {
      final _ = _pending.remove(uri);
      client.close();
    }
  }

  Future<ReleaseImageData> _fetch(http.Client client, Uri uri) async {
    for (var redirects = 0; redirects <= 3; redirects++) {
      if (!isTrustedReleaseImageUri(uri)) {
        throw const FormatException('Untrusted release image redirect');
      }
      final response = await client.send(
        http.Request('GET', uri)
          ..followRedirects = false
          ..headers['accept'] = 'image/png, image/jpeg, image/webp',
      );
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.listen((_) {}).cancel();
        if (location == null) {
          throw const FormatException('Missing image redirect');
        }
        uri = uri.resolve(location);
        continue;
      }
      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes ||
          (contentType != null &&
              !const {
                'image/png',
                'image/jpeg',
                'image/webp',
                'application/octet-stream',
              }.contains(contentType))) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException('Invalid release image response');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (builder.length + chunk.length > maxBytes) {
          throw const FormatException('Release image exceeds size limit');
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      final png =
          bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final webp =
          bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      if (!png && !jpeg && !webp) {
        throw const FormatException('Unsupported release image');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final width = descriptor.width;
        final height = descriptor.height;
        if (width <= 0 ||
            height <= 0 ||
            width > 8192 ||
            height > 8192 ||
            width * height > 20000000) {
          throw const FormatException('Release image dimensions exceed limit');
        }
        // A readable header is not proof that the raster decodes. Validate a
        // bounded first frame before putting successful bytes in the cache.
        final scale = math.min(1.0, 960 / math.max(width, height));
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (width * scale).round()),
          targetHeight: math.max(1, (height * scale).round()),
        );
        try {
          if (codec.frameCount > 1) {
            throw const FormatException(
              'Animated release images are unsupported',
            );
          }
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
        return ReleaseImageData(bytes, width, height);
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
    }
    throw const FormatException('Too many image redirects');
  }
}
