from __future__ import annotations

import hashlib
import os


def make_salt() -> str:
    return os.urandom(16).hex()


def hash_password(password: str, salt_hex: str) -> str:
    # Simple SHA-256(salt + password) for thesis prototype.
    # (Not production-grade; good enough for local demo.)
    h = hashlib.sha256()
    h.update(bytes.fromhex(salt_hex))
    h.update(password.encode("utf-8"))
    return h.hexdigest()


def verify_password(password: str, salt_hex: str, expected_hash: str) -> bool:
    return hash_password(password, salt_hex) == expected_hash

