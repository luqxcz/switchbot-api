import os
import json
import time
import hashlib
import hmac
import base64
import uuid
from typing import Dict


def _get_env(key: str) -> str:
    value = os.getenv(key)
    if not value:
        raise RuntimeError('Missing environment variable: {}'.format(key))
    return value


def build_headers() -> Dict[str, str]:
    token = _get_env('SWITCHBOT_TOKEN')
    secret = _get_env('SWITCHBOT_SECRET')

    nonce = str(uuid.uuid4())
    timestamp_ms = str(int(round(time.time() * 1000)))
    string_to_sign = '{}{}{}'.format(token, timestamp_ms, nonce)

    message = string_to_sign.encode('utf-8')
    secret_bytes = secret.encode('utf-8')
    signature = base64.b64encode(hmac.new(secret_bytes, msg=message, digestmod=hashlib.sha256).digest()).decode('utf-8')

    headers: Dict[str, str] = {}
    headers['Authorization'] = token
    headers['Content-Type'] = 'application/json'
    headers['charset'] = 'utf8'
    headers['t'] = timestamp_ms
    headers['sign'] = signature
    headers['nonce'] = nonce
    return headers


if __name__ == '__main__':
    # Simple diagnostic to show current headers (without making an API call)
    try:
        headers = build_headers()
        print(json.dumps(headers, indent=2))
    except Exception as exc:
        print('Error: {}'.format(exc))