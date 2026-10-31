import base64
from contextlib import nullcontext
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


SCRIPT = Path(__file__).with_name('package.py')
OPENSSL = os.environ.get('OPENSSL_BIN') or shutil.which('openssl')
COMMIT = '0123456789abcdef0123456789abcdef01234567'


class PackageTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not OPENSSL:
            raise RuntimeError('OpenSSL is required to run packaging tests')
        cls.keys = tempfile.TemporaryDirectory(prefix='root-module-test-keys-')
        cls.addClassCleanup(cls.keys.cleanup)
        cls.private = Path(cls.keys.name) / 'temporary-test-key.pem'
        cls.other = Path(cls.keys.name) / 'temporary-other-key.pem'
        for key in [cls.private, cls.other]:
            subprocess.run([OPENSSL, 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:3072', '-out', str(key)], check=True, capture_output=True)
        cls.public_der = subprocess.run([OPENSSL, 'pkey', '-in', str(cls.private), '-pubout', '-outform', 'DER'], check=True, capture_output=True).stdout
        cls.public_b64 = base64.b64encode(cls.public_der).decode('ascii')

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='root-module-package-test-')
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.binary = self.directory / 'etonify-root'
        header = bytearray(64)
        header[:7] = b'\x7fELF\x02\x01\x01'
        header[16:20] = b'\x03\x00\xb7\x00'
        self.binary.write_bytes(header + b'temporary-test-fixture-not-executable')
        self.output = self.directory / 'etonify-root-arm64-v8a.zip'

    def run_package(self, *extra, key=True, public=None):
        env = os.environ.copy()
        env['ROOT_MODULE_SIGNING_KEY'] = self.private.read_text() if key else ''
        env['ROOT_MODULE_PUBLIC_KEY'] = self.public_b64 if public is None else public
        return subprocess.run([sys.executable, '-B', str(SCRIPT), '--openssl', OPENSSL, '--binary', str(self.binary), '--core-commit', COMMIT, '--output', str(self.output), *extra], env=env, capture_output=True, text=True)

    def verify(self, archive):
        return subprocess.run([sys.executable, '-B', str(SCRIPT), '--openssl', OPENSSL, '--verify', str(archive)], env={**os.environ, 'ROOT_MODULE_PUBLIC_KEY': self.public_b64}, capture_output=True, text=True)

    def test_signed_archive_has_exact_manifest_and_independently_valid_signature(self):
        result = self.run_package()
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.namelist(), ['manifest.json', 'manifest.sig', 'etonify-root'])
            manifest_bytes = archive.read('manifest.json')
            signature = archive.read('manifest.sig')
            self.assertEqual(len(signature), 384)
            self.assertEqual(archive.read('etonify-root'), self.binary.read_bytes())
            self.assertEqual(json.loads(manifest_bytes), {
                'protocol': 1,
                'moduleVersion': '0.1.0',
                'versionCode': 1,
                'coreCommit': COMMIT,
                'abi': 'arm64-v8a',
                'minAndroidApi': 26,
                'minClientVersionCode': 42,
                'files': [{'path': 'etonify-root', 'size': self.binary.stat().st_size, 'sha256': hashlib.sha256(self.binary.read_bytes()).hexdigest()}],
            })
        public = self.directory / 'public.der'
        public.write_bytes(self.public_der)
        manifest = self.directory / 'manifest.json'
        manifest.write_bytes(manifest_bytes)
        signature_file = self.directory / 'manifest.sig'
        signature_file.write_bytes(signature)
        verified = subprocess.run([OPENSSL, 'dgst', '-sha256', '-verify', str(public), '-keyform', 'DER', '-signature', str(signature_file), str(manifest)], capture_output=True)
        self.assertEqual(verified.returncode, 0)
        self.assertEqual(self.verify(self.output).returncode, 0)

    def test_binary_or_manifest_tamper_is_rejected(self):
        self.assertEqual(self.run_package().returncode, 0)
        with zipfile.ZipFile(self.output) as archive:
            entries = {name: archive.read(name) for name in archive.namelist()}
        for name in ['etonify-root', 'manifest.json']:
            tampered = self.directory / f'tampered-{name}.zip'
            with zipfile.ZipFile(tampered, 'w') as archive:
                for entry, data in entries.items():
                    archive.writestr(entry, data + b' ' if entry == name else data)
            self.assertNotEqual(self.verify(tampered).returncode, 0)

    def test_module_version_and_version_code_are_bound_into_signed_manifest(self):
        result = self.run_package('--module-version', '0.2.3', '--version-code', '7')
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(self.output) as archive:
            manifest = json.loads(archive.read('manifest.json'))
            self.assertEqual(manifest['moduleVersion'], '0.2.3')
            self.assertEqual(manifest['versionCode'], 7)
        self.assertEqual(self.verify(self.output).returncode, 0)

    def test_rejects_invalid_or_shell_unsafe_version_metadata(self):
        for version, code in [('0.2.0;id', '2'), ('../1.0.0', '2'), ('1.2', '2'), ('01.2.3', '2'), ('0.2.3-rc.1', '2'), ('1.2.3', '0'), ('1.2.3', '-1'), ('1.2.3', '2147483648')]:
            result = self.run_package('--module-version', version, '--version-code', code)
            self.assertNotEqual(result.returncode, 0, (version, code))
            self.assertFalse(self.output.exists())

    def test_missing_signing_key_fails_without_creating_archive(self):
        result = self.run_package(key=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())
        self.assertIn('signing_not_configured', result.stderr)

    def test_wrong_public_key_cannot_sign_and_secrets_are_not_logged(self):
        other_der = subprocess.run([OPENSSL, 'pkey', '-in', str(self.other), '-pubout', '-outform', 'DER'], check=True, capture_output=True).stdout
        result = self.run_package(public=base64.b64encode(other_der).decode('ascii'))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())
        self.assertIn('signing_key_mismatch', result.stderr)
        self.assertNotIn('PRIVATE KEY', result.stdout + result.stderr)
        self.assertNotIn(self.private.read_text().splitlines()[1], result.stdout + result.stderr)

    def test_rejects_missing_public_key_invalid_commit_and_wrong_abi(self):
        self.assertNotEqual(self.run_package(public='').returncode, 0)
        self.assertNotEqual(self.run_package('--core-commit', '../main').returncode, 0)
        self.binary.write_bytes(b'not-an-arm64-ELF')
        self.assertNotEqual(self.run_package().returncode, 0)
        self.assertFalse(self.output.exists())

    def test_refuses_to_overwrite_an_existing_release_archive(self):
        self.output.write_bytes(b'existing-release')
        result = self.run_package()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_bytes(), b'existing-release')

    def test_duplicate_and_extra_archive_entries_are_rejected(self):
        self.assertEqual(self.run_package().returncode, 0)
        for entry in ['unexpected', 'manifest.json']:
            altered = self.directory / f'extra-{entry}.zip'
            shutil.copyfile(self.output, altered)
            expected_warning = self.assertWarns(UserWarning) if entry == 'manifest.json' else nullcontext()
            with expected_warning, zipfile.ZipFile(altered, 'a') as archive:
                archive.writestr(entry, b'not-trusted')
            self.assertNotEqual(self.verify(altered).returncode, 0)


if __name__ == '__main__':
    unittest.main()
