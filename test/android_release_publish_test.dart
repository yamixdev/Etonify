import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _builtSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  final bash = Platform.isWindows
      ? 'C:/Program Files/Git/bin/bash.exe'
      : '/bin/bash';
  final unavailable = !File(bash).existsSync();

  Future<ProcessResult> publish({
    String refs = '',
    String tagSha = _builtSha,
    bool existingRelease = false,
    bool apiFailure = false,
    bool tagClaimConflict = false,
  }) async {
    final workspace = Directory.systemTemp.createTempSync('release-publish-');
    addTearDown(() => workspace.deleteSync(recursive: true));
    Directory('${workspace.path}/build').createSync();
    final source = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();
    final step = source
        .substring(
          source.indexOf('      - name: Create or update draft GitHub Release'),
        )
        .split('\n');
    final run = step.indexWhere((line) => line.trim() == 'run: |');
    expect(run, greaterThan(0));
    final commands = step
        .skip(run + 1)
        .takeWhile(
          (line) => line.trim().isEmpty || line.startsWith('          '),
        )
        .map((line) => line.length >= 10 ? line.substring(10) : '')
        .join('\n');
    return Process.run(
      bash,
      [
        '-e',
        '-o',
        'pipefail',
        '-c',
        '''
gh() {
  if [[ "\$1" == api ]]; then
    if [[ "\$FAKE_API_FAILURE" == true ]]; then return 1; fi
    if [[ "\$2" == --method ]]; then
      if [[ "\$FAKE_TAG_CONFLICT" == true ]]; then return 1; fi
      printf 'TAG_CLAIM'
      printf ' <%s>' "\$@"
      printf '\\n'
      return 0
    fi
    if [[ "\$2" == *matching-refs* ]]; then
      printf '%s\\n' "\$FAKE_REFS"
    else
      printf '%s\\n' "\$FAKE_TAG_SHA"
    fi
  elif [[ "\$1 \$2" == 'release view' ]]; then
    [[ "\$FAKE_RELEASE" == true ]]
  else
    printf 'MUTATION'
    printf ' <%s>' "\$@"
    printf '\\n'
  fi
}
$commands
''',
      ],
      workingDirectory: workspace.path,
      environment: {
        'GITHUB_SHA': _builtSha,
        'GITHUB_REPOSITORY': 'example/client',
        'TAG_NAME': '0.3.9',
        'RELEASE_VERSION': '0.3.9',
        'RELEASE_TITLE': 'v0.3.9',
        'FAKE_REFS': refs,
        'FAKE_TAG_SHA': tagSha,
        'FAKE_RELEASE': '$existingRelease',
        'FAKE_API_FAILURE': '$apiFailure',
        'FAKE_TAG_CONFLICT': '$tagClaimConflict',
      },
    );
  }

  test(
    'new release targets the exact built commit despite a prefix tag',
    () async {
      final result = await publish(refs: 'refs/tags/0.3.90');
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('<create> <0.3.9>'));
      expect(result.stdout, contains('<--target> <$_builtSha>'));
      expect(result.stdout, contains('<ref=refs/tags/0.3.9>'));
      expect(result.stdout, contains('<sha=$_builtSha>'));
    },
    skip: unavailable,
  );

  test('existing mismatched tag prevents all release mutations', () async {
    final result = await publish(
      refs: 'refs/tags/0.3.9',
      tagSha: _otherSha,
      existingRelease: true,
    );
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains('MUTATION')));
  }, skip: unavailable);

  test(
    'matching tag permits updating artifacts from the same commit',
    () async {
      final result = await publish(
        refs: 'refs/tags/0.3.9',
        existingRelease: true,
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('<edit> <0.3.9>'));
      expect(result.stdout, contains('<upload> <0.3.9>'));
    },
    skip: unavailable,
  );

  test('existing draft without a tag also targets the built commit', () async {
    final result = await publish(existingRelease: true);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, contains('<edit> <0.3.9>'));
    expect(result.stdout, contains('<--target> <$_builtSha>'));
  }, skip: unavailable);

  test('tag lookup failure is not treated as a missing tag', () async {
    final result = await publish(apiFailure: true);
    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains('MUTATION')));
  }, skip: unavailable);

  test(
    'concurrent tag creation aborts before editing or uploading a release',
    () async {
      final result = await publish(
        existingRelease: true,
        tagClaimConflict: true,
      );
      expect(result.exitCode, isNot(0));
      expect(result.stdout, isNot(contains('MUTATION')));
    },
    skip: unavailable,
  );
}
