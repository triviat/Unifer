# Unifer sync protocol (relay + E2EE)

This document specifies the cross-device clipboard sync between macOS and Android clients and a minimal **blind relay** server. Plaintext never leaves devices in recoverable form for the operator.

## Goals

- **Confidentiality**: relay and storage see only ciphertext + routing metadata.
- **Authentication**: only paired devices for a vault can read/write ciphertext frames.
- **Forward secrecy (optional phase)**: session keys rotated; out of scope for v0 wire format beyond versioning hooks.
- **Degraded Android behavior**: Android may not read clipboard in background; clients must support explicit “push/pull now” and optional foreground service UX.

## Roles

- **Device**: macOS or Android app with local vault key material.
- **Relay**: stateless-ish WebSocket/HTTP service that routes **envelopes** by `vault_id` and `device_id` without decrypting payloads.

## Pairing and vault keys (v0)

1. User creates a **vault** on a trusted device (Mac). App generates:
   - `vault_id`: random UUID string.
   - `vault_key`: 32-byte random key (XChaCha20-Poly1305 master key for payload encryption).
2. Mac shows **QR** encoding a `unifer://pair` URL, e.g.  
   `unifer://pair?v=<vault_id>&k=<base64url(vault_key)>`  
   (v0 convenience; production should use short-lived SPAKE2/Noise handshake instead of static key in QR.)
3. Android scans QR, imports `vault_id` + `vault_key`, registers `device_id` with relay.

## Wire envelope (v0)

All frames are JSON with base64 fields, transported over **WebSocket** `wss://` (preferred) or HTTPS long-poll fallback.

```json
{
  "v": 1,
  "vault_id": "uuid",
  "from_device": "uuid",
  "ts": 1710000000000,
  "nonce": "base64(24 bytes)",
  "ciphertext": "base64(variable)",
  "aad_hint": "clipboard_item_v1"
}
```

- **`nonce`**: unique per message (192-bit for XChaCha20-Poly1305).
- **`ciphertext`**: encrypts a **payload blob** (see below) with key `vault_key`.
- **`aad_hint`**: informational; true AAD is a canonical byte string `v|vault_id|from_device|ts|aad_hint` on clients.

## Payload blob (inside ciphertext)

Binary layout (versioned):

| Field | Type | Notes |
|------|------|-------|
| `pv` | u8 | payload version (=1) |
| `kind` | u8 | 1=text 2=rtf 3=html 4=png 5=file-uri 6=mixed-manifest |
| `created_ms` | i64 | original capture time |
| `source_bundle` | len-prefixed utf8 | optional |
| `body` | len-prefixed bytes | primary bytes (text or image or manifest JSON) |

For **mixed-manifest** (`kind=6`), `body` is JSON mirroring the macOS on-disk manifest: map of UTI → base64(data), size-capped per device settings.

## Relay API (HTTP bootstrap)

- `POST /v1/vaults` → creates `vault_id` placeholder (optional when vault is purely client-generated).
- `POST /v1/devices` body `{vault_id, device_pubkey_or_id}` → registers device (v0 may use static device UUID + vault-scoped token).
- `GET /v1/ws?vault_id=...&device_id=...&token=...` → WebSocket upgrade.

Relay validates token, then only forwards envelopes to other devices in the same `vault_id`.

## Authorization token (v0)

HMAC-SHA256(`vault_key`, `device_id|issued_at`) truncated to 16 bytes, encoded base64url; relay stores only token hash **per device** if server-assisted registration is enabled. Self-hosted relay may skip persistence and trust pre-shared token file.

## Conflict policy

- **Clipboard items** are immutable events with `created_ms` and monotonic `seq` per device.
- Relay does not merge; clients append. Last duplicate content hash may be dropped as optimization.

## Android foreground constraints

- Document in client UX: “Sync requires foreground” on Android 10+ unless OEM permits; expose **Sync now** action bound to `ClipboardManager` read.

## Versioning

- Bump `v` on envelope for breaking changes; clients ignore unknown `v` with telemetry flag.

## macOS client mapping

- After local SQLite insert, optionally enqueue encrypted envelope for `vault_id` if sync enabled.
- On receive, decrypt, verify AAD, write through same repository path used for local captures.

## Security notes for production

- Replace static QR key transport with **Noise_XX** or **SPAKE2** + out-of-band short code.
- Add **device revocation** list per vault.
- Rotate relay TLS keys; pin optional enterprise relay cert.
