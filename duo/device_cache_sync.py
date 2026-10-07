import duo_client

import argparse
import csv
import json
import re
import sys

__version__ = '1.1.2'
script_title = "Duo Device Sync Script"

"""
NOTICE:
If you are receiving errors while running this script
you can try to run it in a virtual environment as it will
ensure that the duo_client is installed with the necessary
dependencies. Commands to run are:

python3 -m venv .VIRTUAL # Sets up your virtual environment
source .VIRTUAL/bin/activate # configures your shell to make use of this Python environment
pip install duo_client # installs the module 
python ~/Downloads/device_cache_sync.py --infile <file name>.csv # execute the script.
deactivate # stop using the python environment in your current shell
"""

import os

# Credentials come from the environment so this file holds no secrets:
# DUO_MKEY (integration key ID, starts with DM), DUO_IKEY, DUO_SKEY and DUO_API_HOST.
MKEY_CREDENTIALS = {
    os.environ['DUO_MKEY']: {
        'API_IKEY': os.environ['DUO_IKEY'],
        'API_SKEY': os.environ['DUO_SKEY'],
        'API_HOST': os.environ['DUO_API_HOST'],
    }
}
CACHE_URL_FORMAT = '/device/v1/management_systems/{}/device_cache/{}'
MAX_IDENTIFIER_UPLOAD = 1000  # 1000 is the maximum to prevent resource exhaustion


def log_stderr(msg):
    sys.stderr.write(msg)
    sys.stderr.write('\n')


class SyncError(RuntimeError):
    pass


def arg_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--infile',
        required=True,
        help='The path to the input CSV file. Supported formats, .csv'
    )
    parser.add_argument(
        '--device_id_column',
        default='device_id',
        help='The name of the column in the csv file that has the device ID',
    )
    parser.add_argument(
        '--dry_run',
        action=argparse.BooleanOptionalAction,
        default=False,
        help='Test uploading device identifiers but delete new cache '
             'instead of activating it',
    )
    parser.add_argument(
        '--delete_existing_cache',
        action=argparse.BooleanOptionalAction,
        default=False,
        help='If a new cache can\'t be created because one already exists, '
             'delete the existing, in-active cache',
    )
    parser.add_argument(
        '--mkey',
        required=len(MKEY_CREDENTIALS.keys())>1,
        help='The mkey to sync.',
        choices=MKEY_CREDENTIALS.keys()
    )
    return parser


def sync(mkey, device_api, csvfile, args):
    print("Starting device sync")
    try:
        return _sync(mkey, device_api, csvfile, args)
    except RuntimeError as e:
        if getattr(e, 'status', None) == 401:
            raise SyncError(f"Invalid Credentials: {e}")
        raise e


def _sync(mkey, device_api, csvfile, args):
    # Create a new, non-active cache to upload identifiers into.
    cache_key = create_cache(mkey, device_api, args.delete_existing_cache)

    try:
        # Upload the identifiers from the CSV file into the cache.
        result = upload_identifiers(
            device_api, mkey, cache_key, csvfile, args.device_id_column)
    except Exception as e:
        delete_cache(device_api, mkey, cache_key)
        raise e

    if not args.dry_run:
        # Make the new cache active. The currently active cache will be deleted.
        activate_cache(device_api, mkey, cache_key)
    else:
        # Delete the inactive cache.
        delete_cache(device_api, mkey, cache_key)
    
    return result


def create_cache(mkey, device_api, delete_existing=False, log_error=log_stderr):
    try:
        print(f"Attempting to create new cache for mkey: {mkey}")
        result = device_api.json_api_call(
            'POST',
            '/device/v1/management_systems/{}/device_cache'.format(mkey), {}
        )
        cache_key = result['cache_key']
        print(f"New cache created cache_key: {cache_key}")
        return cache_key

    except RuntimeError as e:
        data = getattr(e, 'data', {})
        if isinstance(data, str):
              msg = data
        elif 'messsage_detail' in data:
            msg = data.get('message_detail')
        else:
            msg = data.get('message')

        if getattr(e, 'status', None) == 409 and delete_existing:
            message_detail = getattr(e, 'data', {}).get('message_detail')
            existing_cache_url = re.search(
                r"(?P<url>https://[^\s]+)", message_detail).group("url")
            existing_cache_key = existing_cache_url.split('/')[-1]
            delete_cache(device_api, mkey, cache_key=existing_cache_key)
            # Try again.
            return create_cache(
                mkey, device_api, delete_existing=False, log_error=log_error)
        elif msg:
            error = SyncError(msg)
            error.status = e.status
            raise error
        raise e


def delete_cache(device_api, mkey, cache_key):
    print(f"Attempting to delete existing cache cache_key:{cache_key}")
    result = device_api.json_api_call(
        'DELETE',
        CACHE_URL_FORMAT.format(mkey, cache_key),
        {}
    )
    print(f"Deleted existing cache cache_key: {cache_key}")
    return result


def activate_cache(device_api, mkey, cache_key):
    print(f'Attempting to activate device cache cache_key: {cache_key}')
    result = device_api.json_api_call(
        'POST',
        (CACHE_URL_FORMAT + '/activate').format(mkey, cache_key),
        {}
    )
    print(f'Activated device cache cache_key: {cache_key}')
    return result

def divide_chunks(device_ids, max_upload):
    for i in range(0, len(device_ids), max_upload):
        yield device_ids[i:i + max_upload]

def upload_identifiers(device_api, mkey, cache_key, csvfile, device_id_column):
    # If 404 someone deleted it during upload.
    reader = csv.DictReader(csvfile, skipinitialspace=True)
    count = 0
    
    while True:
        device_ids = []
        for row in reader:
            if row[device_id_column]:
                device_ids.append({'device_id': row[device_id_column]})

        if not device_ids:
            break
        
        length = len(device_ids)

        try:
            print(f"Attempting to upload devices count: {length}")

            # We want to make POST requests in chunks of 1000 devices or less
            # because that's max amount of devices we can POST at a time.
            for i in divide_chunks(device_ids, MAX_IDENTIFIER_UPLOAD):
                result = device_api.json_api_call(
                        'POST',
                        (CACHE_URL_FORMAT + '/devices').format(mkey, cache_key),
                        {'devices': json.dumps(i)}
                    )
                count = result['device_count']
                print(f"Uploading {len(i)} device(s)")

            # Device count may not match the device ids being uploaded due to id replication
            print(f"{count} devices uploaded")

        except RuntimeError as e:
            if getattr(e, 'status', None) == 400:
                raise SyncError(getattr(e, 'data', {}).get('message_detail'))
            else:
                raise e

    if count == 0:
        raise SyncError(
            f'No device IDs read from input column: {device_id_column}')

    return {'device_count': count}

def default_mkey():
    if len(MKEY_CREDENTIALS.keys()) == 1:
        return (list(MKEY_CREDENTIALS.keys())[0])

def main():
    parser = arg_parser()
    args = parser.parse_args()
    user_agent = f'Duo Device Python api/{__version__} (duo_client=={duo_client.__version__})'
    mkey = args.mkey if args.mkey else default_mkey()

    device_api = duo_client.client.Client(
        ikey=MKEY_CREDENTIALS[mkey]['API_IKEY'],
        skey=MKEY_CREDENTIALS[mkey]['API_SKEY'],
        host=MKEY_CREDENTIALS[mkey]['API_HOST'],
        user_agent=user_agent,
        sig_version=2,
    )
        
    # does infile exist and is readable?
    # Open passing the encoding utf-8-sig to handle standard and UTF-8 formats. 
    with open(args.infile, encoding='utf-8-sig') as csvfile: 
        try:
            print(
                f"Starting {script_title} Version: {__version__}"
                + f" Duo_Client Version: {duo_client.__version__}")
            result = sync(mkey, device_api, csvfile, args)
            if result and 'device_count' in result:
                count = result['device_count']
                print(f'Devices synced: {count}')
        except SyncError as e:
            print(e)
            sys.exit(1)

if __name__ == '__main__':
    main()