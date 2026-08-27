#!/usr/bin/env python3
import base64
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

import win32crypt
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

CACHE_MAX_AGE_SECONDS = 300
CACHE_STALE_MAX_AGE_SECONDS = 24 * 60 * 60


def claude_root():
    return os.path.join(
        os.environ["LOCALAPPDATA"],
        "Packages",
        "Claude_pzs8sxrjxfjjc",
        "LocalCache",
        "Roaming",
        "Claude",
    )


def cache_path():
    return os.path.join(
        os.environ["LOCALAPPDATA"],
        "CodexQuotaGauge",
        "claude-usage-cache.json",
    )


def parse_timestamp(value):
    if not value:
        return None
    text = str(value)
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def load_cached_usage(max_age_seconds=None):
    path = cache_path()
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            cached = json.load(f)
    except (OSError, json.JSONDecodeError):
        return None

    if not cached.get("available"):
        return None

    updated_at = parse_timestamp(cached.get("updated_at"))
    if not updated_at:
        return None

    age = (datetime.now(timezone.utc) - updated_at).total_seconds()
    if max_age_seconds is not None and age > max_age_seconds:
        return None
    if age > CACHE_STALE_MAX_AGE_SECONDS:
        return None

    return cached


def save_cached_usage(payload):
    path = cache_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, separators=(",", ":"))


def decrypt_desktop_token_cache(root):
    config_path = os.path.join(root, "config.json")
    state_path = os.path.join(root, "Local State")

    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)
    with open(state_path, "r", encoding="utf-8") as f:
        state = json.load(f)

    encrypted_key = base64.b64decode(state["os_crypt"]["encrypted_key"])
    if encrypted_key.startswith(b"DPAPI"):
        encrypted_key = encrypted_key[5:]
    key = win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]

    encrypted_cache = base64.b64decode(config["oauth:tokenCache"])
    if encrypted_cache[:3] != b"v10":
        raise RuntimeError("Unsupported Claude token cache format")

    plaintext = AESGCM(key).decrypt(encrypted_cache[3:15], encrypted_cache[15:], None)
    return json.loads(plaintext.decode("utf-8"))


def choose_token(cache):
    preferred = None
    fallback = None
    for key, value in cache.items():
        if not isinstance(value, dict) or not value.get("token"):
            continue
        fallback = fallback or value
        if "user:sessions:claude_code" in key:
            preferred = value
            break
    selected = preferred or fallback
    if not selected:
        raise RuntimeError("No Claude Desktop OAuth token found")
    return selected["token"]


def read_usage(token):
    request = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={
            "Authorization": "Bearer " + token,
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "codex-quota-gauge/1.0",
        },
    )
    with urllib.request.urlopen(request, timeout=12) as response:
        return json.loads(response.read().decode("utf-8"))


def remaining(entry):
    if not isinstance(entry, dict):
        return -1
    used = entry.get("utilization")
    if used is None:
        return -1
    return max(0, min(100, 100 - round(float(used))))


def main():
    cached = load_cached_usage(CACHE_MAX_AGE_SECONDS)
    if cached:
        cached["cached"] = True
        cached["stale"] = False
        print(json.dumps(cached, separators=(",", ":")))
        return 0

    try:
        root = claude_root()
        cache = decrypt_desktop_token_cache(root)
        token = choose_token(cache)
        usage = read_usage(token)
        out = {
            "available": True,
            "five_hour_remaining_percent": remaining(usage.get("five_hour")),
            "five_hour_resets_at": (usage.get("five_hour") or {}).get("resets_at"),
            "weekly_remaining_percent": remaining(usage.get("seven_day")),
            "weekly_resets_at": (usage.get("seven_day") or {}).get("resets_at"),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        save_cached_usage(out)
        print(json.dumps(out, separators=(",", ":")))
    except Exception as exc:
        cached = load_cached_usage()
        if cached:
            cached["cached"] = True
            cached["stale"] = True
            cached["error"] = str(exc)
            print(json.dumps(cached, separators=(",", ":")))
            return 0
        print(json.dumps({"available": False, "error": str(exc)}, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
