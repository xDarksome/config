import sys
from bech32 import bech32_encode, convertbits

raw = bytes.fromhex(sys.stdin.read().strip())

if len(raw) != 32:
    raise ValueError(f"expected 32 bytes, got {len(raw)}")

words = convertbits(raw, 8, 5, True)
identity = bech32_encode("age-secret-key-", words)

print(identity.upper())
