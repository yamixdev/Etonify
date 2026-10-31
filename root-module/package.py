"""Package protocol-1 arm64 root modules; private signing keys are never generated."""

import argparse
import base64
import binascii
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile


MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
MAX_MANIFEST_BYTES = 64 * 1024
ENTRIES = ['manifest.json', 'manifest.sig', 'etonify-root']


class PackageError(Exception):
    pass


def openssl_run(openssl, arguments, *, error):
    environment = os.environ.copy()
    environment.pop('ROOT_MODULE_SIGNING_KEY', None)
    try:
        result = subprocess.run([openssl, *arguments], capture_output=True, timeout=30, env=environment)
    except (OSError, subprocess.TimeoutExpired):
        raise PackageError(error) from None
    if result.returncode:
        raise PackageError(error)
    return result.stdout


def public_key_bytes(encoded):
    if not encoded or len(encoded) > 8192:
        raise PackageError('signing_not_configured')
    try:
        return base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error):
        raise PackageError('signing_key_invalid') from None


def validate_binary(binary):
    if len(binary) < 64 or len(binary) > MAX_ARCHIVE_BYTES - MAX_MANIFEST_BYTES:
        raise PackageError('binary_size_invalid')
    if binary[:7] != b'\x7fELF\x02\x01\x01' or binary[18:20] != b'\xb7\x00':
        raise PackageError('binary_abi_invalid')


def validate_version(module_version, version_code):
    if not isinstance(module_version, str) or not re.fullmatch(r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)', module_version) or len(module_version) > 64:
        raise PackageError('module_version_invalid')
    if type(version_code) is not int or not 1 <= version_code <= 2147483647:
        raise PackageError('version_code_invalid')


def validate_manifest(manifest, binary):
    expected_keys = {'protocol', 'moduleVersion', 'versionCode', 'coreCommit', 'abi', 'minAndroidApi', 'minClientVersionCode', 'files'}
    if not isinstance(manifest, dict) or set(manifest) != expected_keys:
        raise PackageError('manifest_invalid')
    for name, expected in [('protocol', 1), ('minAndroidApi', 26), ('minClientVersionCode', 42)]:
        if type(manifest[name]) is not int or manifest[name] != expected:
            raise PackageError('manifest_invalid')
    validate_version(manifest['moduleVersion'], manifest['versionCode'])
    if manifest['abi'] != 'arm64-v8a' or not isinstance(manifest['coreCommit'], str) or not re.fullmatch('[0-9a-f]{40}', manifest['coreCommit']):
        raise PackageError('manifest_invalid')
    expected_file = {'path': 'etonify-root', 'size': len(binary), 'sha256': hashlib.sha256(binary).hexdigest()}
    files = manifest['files']
    if files != [expected_file] or type(files[0].get('size')) is not int:
        raise PackageError('binary_hash_mismatch')
    validate_binary(binary)


def verify_package(archive_path, public_key, openssl):
    trusted = public_key_bytes(public_key)
    if archive_path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise PackageError('archive_size_invalid')
    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
        if len(entries) != 3 or set(entry.filename for entry in entries) != set(ENTRIES) or any(entry.is_dir() or stat.S_ISLNK(entry.external_attr >> 16) for entry in entries):
            raise PackageError('archive_entry_invalid')
        if archive.getinfo('manifest.json').file_size > MAX_MANIFEST_BYTES or archive.getinfo('manifest.sig').file_size != 384 or archive.getinfo('etonify-root').file_size > MAX_ARCHIVE_BYTES - MAX_MANIFEST_BYTES:
            raise PackageError('archive_size_invalid')
        manifest_bytes = archive.read('manifest.json')
        signature = archive.read('manifest.sig')
        binary = archive.read('etonify-root')
    with tempfile.TemporaryDirectory(prefix='root-module-verify-') as temporary:
        directory = Path(temporary)
        public = directory / 'public.der'
        public.write_bytes(trusted)
        manifest_file = directory / 'manifest.json'
        manifest_file.write_bytes(manifest_bytes)
        signature_file = directory / 'manifest.sig'
        signature_file.write_bytes(signature)
        openssl_run(openssl, ['rsa', '-pubin', '-inform', 'DER', '-in', str(public), '-noout'], error='signing_key_invalid')
        openssl_run(openssl, ['dgst', '-sha256', '-verify', str(public), '-keyform', 'DER', '-signature', str(signature_file), str(manifest_file)], error='signature_invalid')
    try:
        manifest = json.loads(manifest_bytes)
    except (UnicodeDecodeError, ValueError):
        raise PackageError('manifest_invalid') from None
    validate_manifest(manifest, binary)
    return manifest


def create_package(binary_path, output_path, core_commit, private_key, public_key, openssl, module_version='0.1.0', version_code=1):
    validate_version(module_version, version_code)
    if not private_key:
        raise PackageError('signing_not_configured')
    trusted = public_key_bytes(public_key)
    if not re.fullmatch('[0-9a-f]{40}', core_commit):
        raise PackageError('core_commit_invalid')
    if output_path.exists() or output_path.is_symlink():
        raise PackageError('output_exists')
    if binary_path.is_symlink() or binary_path.stat().st_size > MAX_ARCHIVE_BYTES - MAX_MANIFEST_BYTES:
        raise PackageError('binary_size_invalid')
    binary = binary_path.read_bytes()
    validate_binary(binary)
    manifest = {
        'protocol': 1,
        'moduleVersion': module_version,
        'versionCode': version_code,
        'coreCommit': core_commit,
        'abi': 'arm64-v8a',
        'minAndroidApi': 26,
        'minClientVersionCode': 42,
        'files': [{'path': 'etonify-root', 'size': len(binary), 'sha256': hashlib.sha256(binary).hexdigest()}],
    }
    manifest_bytes = json.dumps(manifest, separators=(',', ':'), ensure_ascii=True).encode('utf-8')
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='root-module-sign-') as temporary:
        directory = Path(temporary)
        private = directory / 'key.pem'
        descriptor = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w', encoding='ascii', newline='\n') as key_file:
            key_file.write(private_key)
        derived = openssl_run(openssl, ['rsa', '-in', str(private), '-passin', 'pass:', '-pubout', '-outform', 'DER'], error='signing_key_invalid')
        if not hmac.compare_digest(derived, trusted):
            raise PackageError('signing_key_mismatch')
        manifest_file = directory / 'manifest.json'
        manifest_file.write_bytes(manifest_bytes)
        signature = openssl_run(openssl, ['dgst', '-sha256', '-sign', str(private), '-passin', 'pass:', str(manifest_file)], error='signing_failed')
        if len(signature) != 384:
            raise PackageError('signing_key_invalid')
        temporary_zip = directory / 'module.zip'
        with zipfile.ZipFile(temporary_zip, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, data in [('manifest.json', manifest_bytes), ('manifest.sig', signature), ('etonify-root', binary)]:
                entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                entry.create_system = 3
                entry.external_attr = (0o100755 if name == 'etonify-root' else 0o100644) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(entry, data)
        verify_package(temporary_zip, public_key, openssl)
        descriptor = os.open(output_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
        try:
            with os.fdopen(descriptor, 'wb') as target, temporary_zip.open('rb') as source:
                shutil.copyfileobj(source, target)
        except BaseException:
            output_path.unlink(missing_ok=True)
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path)
    parser.add_argument('--core-commit')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--verify', type=Path)
    parser.add_argument('--module-version', default='0.1.0')
    parser.add_argument('--version-code', default=1, type=int)
    parser.add_argument('--validate-metadata', action='store_true')
    parser.add_argument('--openssl', default=os.environ.get('OPENSSL_BIN', 'openssl'))
    arguments = parser.parse_args()
    try:
        if arguments.validate_metadata:
            if arguments.binary or arguments.output or arguments.core_commit or arguments.verify:
                parser.error('--validate-metadata cannot be combined with archive options')
            validate_version(arguments.module_version, arguments.version_code)
            print('Module version metadata validated.')
        elif arguments.verify:
            if arguments.binary or arguments.output or arguments.core_commit:
                parser.error('--verify cannot be combined with packaging options')
            verify_package(arguments.verify, os.environ.get('ROOT_MODULE_PUBLIC_KEY', ''), arguments.openssl)
            print('Root module signature and integrity verified.')
        else:
            if not arguments.binary or not arguments.output or not arguments.core_commit:
                parser.error('--binary, --core-commit and --output are required')
            create_package(arguments.binary, arguments.output, arguments.core_commit, os.environ.get('ROOT_MODULE_SIGNING_KEY', ''), os.environ.get('ROOT_MODULE_PUBLIC_KEY', ''), arguments.openssl, arguments.module_version, arguments.version_code)
            print('Signed root module archive created and verified.')
    except PackageError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, zipfile.BadZipFile):
        print('package_io_or_format_error', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
