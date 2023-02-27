from typing import Any, Tuple
import json
import hashlib
from filelock import FileLock


def set_unsafe(primary_key : str, content : Any):
    # write etag and content
    serialized_content = json.dumps(content)
    with open(_get_path(primary_key), 'w') as fh:
        fh.write(serialized_content)


# NOTE! This doesn't account for multi-threaded access.
def set_safe(primary_key : str, content : Any, etag : str = 'required but not set'):
    if os.path.exists(_get_etag(primary_key)):
        stored_etag = open(_get_etag(primary_key), 'r').read()  # may throw file errors.
        if stored_etag != etag:
            raise ValueError(f"Invalid etag! Someone moved your cheese?\nOld: {stored_etag}\nNew: {etag}")
    # write etag and content
    serialized_content = json.dumps(content)
    new_etag = hashlib.md5(serialized_content.encode('ascii', 'xmlcharrefreplace'))
    with open(_get_etag(primary_key), 'w') as fh:
        fh.write(str(new_etag.hexdigest()))
    with open(_get_path(primary_key), 'w') as fh:
        fh.write(serialized_content)


def set(primary_key : str, content : Any, etag : str = 'required but not set'):
    locker = FileLock(_get_lock(primary_key), timeout=1)
    with locker:
        if os.path.exists(_get_etag(primary_key)):
            stored_etag = open(_get_etag(primary_key), 'r').read()  # may throw file errors.
            if stored_etag != etag:
                raise ValueError(f"Invalid etag! Someone moved your cheese?\nOld: {stored_etag}\nNew: {etag}")
        # write etag and content
        serialized_content = json.dumps(content)
        new_etag = hashlib.md5(serialized_content.encode('ascii', 'xmlcharrefreplace'))

        with open(_get_etag(primary_key), 'w') as fh:
            fh.write(str(new_etag.hexdigest()))
        with open(_get_path(primary_key), 'w') as fh:
            fh.write(serialized_content)


def get(primary_key : str) -> Tuple[Any, str]:
    with open(_get_etag(primary_key), 'r') as fh:
        etag = fh.read()
    with open(_get_path(primary_key), 'r') as fh:
        content = json.loads(fh.read())
    return content, etag


import os
storage_base = os.path.join(os.curdir, "_filestore")
os.makedirs(storage_base, exist_ok=True)

def _get_path(key : str):
    return os.path.join(storage_base, key)

def _get_etag(key : str):
    return os.path.join(storage_base, f'{key}_etag')

def _get_lock(key : str):
    return os.path.join(storage_base, f'{key}_.lock')