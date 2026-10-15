import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/windows/desktop_preferences.dart';
import 'package:meow_client/platform/windows/windows_process_rules.dart';

void main() {
  test('excluded exact Windows paths are canonicalized and deduplicated', () {
    final rules = WindowsProcessRules.build(
      const DesktopModePreferences(
        processPaths: [
          r'C:/Apps/./Foo.EXE',
          r'c:\apps\foo.exe',
          r'D:\Other\foo.exe',
        ],
      ),
    );
    expect(rules, [
      {
        'process_path_regex': [
          r'(?i)^c:\\apps\\foo\.exe$',
          r'(?i)^d:\\other\\foo\.exe$',
        ],
        'outbound': 'direct',
      },
    ]);
  });

  test(
    'only selected routes exact paths to select and unknown processes direct',
    () {
      expect(
        WindowsProcessRules.build(
          const DesktopModePreferences(
            processRoutingMode: ProcessRoutingMode.onlySelected,
            processPaths: [r'C:\Apps\foo.exe'],
          ),
        ),
        [
          {
            'process_path_regex': [r'(?i)^c:\\apps\\foo\.exe$'],
            'outbound': 'select',
          },
          {'outbound': 'direct'},
        ],
      );
      expect(
        WindowsProcessRules.build(
          const DesktopModePreferences(
            processRoutingMode: ProcessRoutingMode.onlySelected,
          ),
        ),
        [
          {'outbound': 'direct'},
        ],
      );
      expect(
        WindowsProcessRules.build(DesktopModePreferences.defaults),
        isEmpty,
      );
    },
  );

  test('UNC executable paths retain their Windows root', () {
    expect(
      WindowsProcessRules.build(
        const DesktopModePreferences(
          processPaths: [r'\\Server\Share\Apps\foo.exe'],
        ),
      ).single['process_path_regex'],
      [r'(?i)^\\\\server\\share\\apps\\foo\.exe$'],
    );
  });

  test(
    'literal regex metacharacters match only exact case-insensitive identity',
    () {
      final pattern =
          (WindowsProcessRules.build(
                    const DesktopModePreferences(
                      processPaths: [r'C:\Apps (1)\foo[bar]+.exe'],
                    ),
                  ).single['process_path_regex']
                  as List<String>)
              .single;
      final matcher = RegExp(pattern.substring(4), caseSensitive: false);
      expect(matcher.hasMatch(r'C:\APPS (1)\Foo[bar]+.EXE'), true);
      expect(matcher.hasMatch(r'D:\Apps (1)\foo[bar]+.exe'), false);
      expect(matcher.hasMatch(r'C:\Apps (1)\foo[bar]+.exe.backup'), false);
      expect(matcher.hasMatch(r'C:\Apps 1\foob.exe'), false);
    },
  );

  for (final path in [
    '',
    'foo.exe',
    r'C:foo.exe',
    r'\foo.exe',
    r'C:\foo.exe:stream',
    r'C:\Apps\*.exe',
    r'C:\Apps\foo.exe ',
    r'C:\..\foo.exe',
    r'\\?\C:\foo.exe',
    r'C:\Apps\CON.exe',
    r'C:\Apps\foo.cmd',
    'C:\\Apps\\foo\u0000.exe',
  ]) {
    test('rejects malformed or ambiguous process path $path', () {
      expect(
        () => WindowsProcessRules.build(
          DesktopModePreferences(processPaths: [path]),
        ),
        throwsFormatException,
      );
    });
  }
}
