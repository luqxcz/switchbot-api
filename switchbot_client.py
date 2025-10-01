import os
import sys
import json
import argparse
from typing import Any, Dict, List

import requests

from auth import build_headers


def _base_url() -> str:
    host = os.getenv('SWITCHBOT_BASE_URL', 'https://api.switch-bot.com')
    version = os.getenv('SWITCHBOT_API_VERSION', 'v1.1')
    return '{}/{}'.format(host.rstrip('/'), version)


def _request(path: str) -> Dict[str, Any]:
    url = '{}{}'.format(_base_url(), path)
    headers = build_headers()
    response = requests.get(url, headers=headers, timeout=15)
    response.raise_for_status()
    return response.json()


def list_devices() -> Dict[str, Any]:
    return _request('/devices')


def get_device_status(device_id: str) -> Dict[str, Any]:
    return _request('/devices/{}/status'.format(device_id))


def print_json(data: Any) -> None:
    print(json.dumps(data, indent=2, ensure_ascii=False))


def cmd_devices(args: argparse.Namespace) -> int:
    try:
        payload = list_devices()
        print_json(payload)
        return 0
    except Exception as exc:
        print('Error fetching devices: {}'.format(exc), file=sys.stderr)
        return 1


def cmd_status(args: argparse.Namespace) -> int:
    if not args.device_id:
        print('--device-id is required for status', file=sys.stderr)
        return 2
    try:
        payload = get_device_status(args.device_id)
        print_json(payload)
        return 0
    except Exception as exc:
        print('Error fetching status for {}: {}'.format(args.device_id, exc), file=sys.stderr)
        return 1


def cmd_status_all(args: argparse.Namespace) -> int:
    try:
        devices = list_devices()
        body = devices.get('body', {})
        device_list: List[Dict[str, Any]] = body.get('deviceList', [])
        results: Dict[str, Any] = {}
        for device in device_list:
            device_id = device.get('deviceId') or device.get('id')
            if not device_id:
                continue
            try:
                status = get_device_status(device_id)
                results[device_id] = status
            except Exception as exc:
                results[device_id] = {'error': str(exc)}
        print_json(results)
        return 0
    except Exception as exc:
        print('Error listing devices: {}'.format(exc), file=sys.stderr)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='SwitchBot API client')
    subparsers = parser.add_subparsers(dest='command')

    p_devices = subparsers.add_parser('devices', help='List devices')
    p_devices.set_defaults(func=cmd_devices)

    p_status = subparsers.add_parser('status', help='Get status for a device')
    p_status.add_argument('--device-id', required=True, help='SwitchBot deviceId')
    p_status.set_defaults(func=cmd_status)

    p_status_all = subparsers.add_parser('status-all', help='Get status for all devices')
    p_status_all.set_defaults(func=cmd_status_all)

    return parser


def main(argv: List[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not hasattr(args, 'func'):
        parser.print_help()
        return 2
    return int(args.func(args))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))


