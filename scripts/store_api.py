"""Small App Store Connect client; credentials remain on the signing host."""
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

HOST = 'https://api.appstoreconnect.apple.com'


class SameHostRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlsplit(newurl)
        if parsed.scheme != 'https' or parsed.netloc != 'api.appstoreconnect.apple.com':
            raise StoreError('Refusing to forward Apple authorization to another host')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class StoreError(RuntimeError):
    pass


def save_private(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            temporary.chmod(0o600)
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def source_fingerprint(root):
    root = Path(root)
    files = sorted((root/'Sources').rglob('*.swift'))
    files += [root/p for p in ['VERSION', 'project.yml', 'store/Info.plist',
              'store/InputPin.entitlements', 'store/PrivacyInfo.xcprivacy', 'scripts/make-icon.swift']]
    digest = hashlib.sha256()
    for path in files:
        name, data = str(path.relative_to(root)).encode(), path.read_bytes()
        digest.update(len(name).to_bytes(8, 'big')+name+len(data).to_bytes(8, 'big')+data)
    return digest.hexdigest()


def raw_signature(der):
    # ES256 signatures from OpenSSL use DER INTEGERs; JWT requires two 32-byte integers.
    if len(der) < 8 or der[0] != 0x30 or der[1] != len(der) - 2:
        raise StoreError('Invalid ES256 signature')
    offset, values = 2, []
    for _ in range(2):
        if offset + 2 > len(der) or der[offset] != 2:
            raise StoreError('Invalid ES256 integer')
        size = der[offset + 1]
        value = der[offset + 2:offset + 2 + size]
        if not value or len(value) != size or value[0] & 128:
            raise StoreError('Invalid ES256 integer length')
        value = value.lstrip(b'\0') or b'\0'
        if len(value) > 32:
            raise StoreError('Require P-256 signing key')
        values.append(value.rjust(32, b'\0'))
        offset += size + 2
    if offset != len(der):
        raise StoreError('Trailing ES256 signature data')
    return b''.join(values)


class StoreAPI:
    def __init__(self, credentials=None):
        self.config_path = Path(credentials or os.environ.get('INPUTPIN_APPLE_CONFIG',
                                     str(Path.home()/'.config/apple-release/account.json'))).expanduser()
        self.config = json.loads(self.config_path.read_text())
        self.key = Path(self.config['private_key_path']).expanduser()
        if not self.key.is_absolute():
            self.key = self.config_path.parent/self.key
        if not self.key.is_file() or self.key.stat().st_mode & 0o077:
            raise StoreError('Private API key must exist and have mode 600')

    def token(self):
        b64 = lambda value: base64.urlsafe_b64encode(value).rstrip(b'=')
        now = int(time.time())
        message = b64(json.dumps({'alg': 'ES256', 'kid': self.config['key_id'], 'typ': 'JWT'}).encode())
        message += b'.' + b64(json.dumps({'iss': self.config['issuer_id'], 'iat': now,
                                         'exp': now + 300, 'aud': 'appstoreconnect-v1'}).encode())
        result = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(self.key)],
                                input=message, capture_output=True, check=True)
        return (message + b'.' + b64(raw_signature(result.stdout))).decode()

    def request(self, method, path, attributes=None, params=None):
        parsed = urllib.parse.urlsplit(path)
        if parsed.scheme or parsed.netloc or not parsed.path.startswith(('/v1/', '/v2/', '/v3/')):
            raise StoreError('Require an App Store Connect resource path')
        if params and parsed.query:
            raise StoreError('Query supplied twice')
        url = HOST + path
        if params:
            url += '?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method,
            data=json.dumps(attributes).encode() if attributes is not None else None,
            headers={'Authorization': 'Bearer ' + self.token(), 'Content-Type': 'application/json'})
        try:
            with urllib.request.build_opener(SameHostRedirect()).open(req, timeout=60) as response:
                body = response.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as error:
            try:
                errors = json.loads(error.read()).get('errors', [])
                detail = '; '.join(e.get('code', '') + ': ' + e.get('detail', e.get('title', '')) for e in errors)
            except (ValueError, TypeError):
                detail = 'Unparseable API error'
            raise StoreError(f'Apple HTTP {error.code}: {detail}') from None

    def get(self, path, **params):
        return self.request('GET', path, params=params or None)

    def all(self, path, **params):
        result = self.get(path, **params)
        items = list(result.get('data', []))
        seen = set()
        while result.get('links', {}).get('next'):
            link = result['links']['next']
            if not link.startswith(HOST + '/'):
                raise StoreError('Unexpected pagination host')
            if link in seen or len(seen) >= 1000:
                raise StoreError('Invalid pagination chain')
            seen.add(link)
            result = self.get(link[len(HOST):])
            items.extend(result.get('data', []))
        return items

    def create(self, kind, attributes=None, relationships=None, included=None):
        data = {'type': kind}
        if attributes is not None:
            data['attributes'] = attributes
        if relationships is not None:
            data['relationships'] = relationships
        payload = {'data': data}
        if included is not None:
            payload['included'] = included
        return self.request('POST', '/v1/' + kind, payload)['data']

    def patch(self, kind, identity, attributes=None, relationships=None):
        data = {'type': kind, 'id': identity}
        if attributes is not None:
            data['attributes'] = attributes
        if relationships is not None:
            data['relationships'] = relationships
        return self.request('PATCH', '/v1/' + kind + '/' + identity, {'data': data})


def relation(kind, identity):
    return {'data': {'type': kind, 'id': identity}}
