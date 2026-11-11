---
name: "tauri-gmail-oauth"
description: "Implements and audits Google OAuth 2.0 authorization-code + PKCE for Gmail in Tauri v2 desktop apps, with Rust-owned tokens, OS keyring storage, and Gmail API calls that never expose tokens to the WebView. Use whenever the user mentions Google login, Gmail API, OAuth, PKCE, refresh tokens, loopback 127.0.0.1, custom URI / deep-link OAuth, tauri-plugin-opener, 'this browser is not secure', disallowed_useragent, invalid_request on /token, Address Already in Use on the callback port, or storing tokens in localStorage in a Tauri/Rust desktop app — even if they do not name Gmail or PKCE."
---

# Tauri v2 + Google Gmail OAuth

Desktop Tauri apps are OAuth **public clients** (RFC 8252). A static `client_secret` in the binary is extractable. Authorization happens in the **system browser**, never in the Tauri WebView. Tokens live in **Rust**; the WebView sees profile data and Gmail payloads, never credentials.

This skill has two modes. Detect from the prompt:

- **Implement** — add or replace the auth stack.
- **Audit** — review existing code against the rules in `references/audit-rules.md`.

## Non-negotiables

These exist because Google and the IETF model desktop apps as hostile to secret storage and WebView login:

1. Client type in Google Cloud Console is **Desktop app**, not Web application.
2. Authorization Code + **PKCE S256** on every authorization request.
3. Open `https://accounts.google.com/o/oauth2/v2/auth` with `tauri-plugin-opener` (or OS equivalent). Fail the change if login uses `WebviewWindow`, `<iframe>`, `window.open`, or a Tauri URL load of accounts.google.com.
4. Token exchange and refresh happen only in Rust (`reqwest` to `https://oauth2.googleapis.com/token`).
5. Persist only the **refresh token** (and account id) in the OS keyring via the `keyring` crate. Keep the access token in process memory. Never write tokens to `localStorage`, `sessionStorage`, IndexedDB, cookies, or plaintext files.
6. Gmail HTTP calls are Rust commands. The frontend sends operation parameters; Rust attaches `Authorization: Bearer` and returns filtered JSON.
7. Identifiers in generated code are English: `start_login`, `check_session`, `logout`, modules under `src-tauri/src/auth/`.

## Google `client_secret` (do not follow naive public-client advice blindly)

Google **issues** a `client_secret` for Desktop clients. Docs mark it optional; the token endpoint frequently returns `invalid_request: client_secret is missing` when it is omitted, even with a valid `code_verifier`.

- Send `client_secret` on `/token` and refresh if the Console provided one.
- Treat it as a **public identifier**, not a confidential server secret: load from env or a gitignored config on the Rust side. Never ship it to the WebView. Never skip PKCE because the secret exists.
- Do not switch the client type to "Web application" just to "use a real secret" with a fixed loopback port. That breaks RFC 8252 and forces exact pre-registered ports.

## Redirect method

Loopback (`http://127.0.0.1:<ephemeral-port>/callback`) and custom URI schemes are **both supported** by Google for Desktop clients. They are not interchangeable inside a single login attempt: `redirect_uri` on `/auth` and `/token` must be byte-for-byte identical.

Choose using the table, then read **one** reference:

| Constraint | Prefer |
|---|---|
| Default when the user did not specify | Loopback — recommended by Google for macOS/Linux/Windows desktop; works in `tauri dev` |
| User wants login to complete after the app was fully quit | Custom URI + `tauri-plugin-single-instance` (Linux/Windows) |
| User is iterating on macOS with `tauri dev` | Loopback — macOS will not deliver custom schemes without a signed `.app` bundle |
| User already has deep-link infrastructure | Custom URI, but still keep token exchange in Rust |
| User asks for both | Implement **one** as the live login redirect. Do not register two `redirect_uri` values for the same in-flight PKCE session |

- Loopback: read `references/loopback.md`
- Custom URI: read `references/deep-link.md` and, on Linux failures, follow the existing `tauri-deep-link-linux` skill (`.desktop` `%u`, `register_all()` vs installed handler)

Loopback deprecation at Google applies to **Android, iOS, and Chrome app** clients. Desktop app + `http://127.0.0.1` remains supported. Prefer the literal `127.0.0.1`, not `localhost` (IPv4 vs IPv6 is a common `invalid_request` cause).

## Implement mode

Read `references/google-console.md` first if credentials or scopes are missing.

### Layout

```
src-tauri/
├── capabilities/default.json
├── Cargo.toml
└── src/
    ├── auth/
    │   ├── mod.rs
    │   ├── pkce.rs
    │   ├── storage.rs
    │   ├── loopback.rs      # if loopback
    │   └── deep_link.rs     # if custom URI
    ├── commands.rs
    └── lib.rs
```

Keep the public surface of `auth` small: `start_login`, `restore_session`, `logout`, `gmail_request`. The WebView never imports PKCE, keyring, or HTTP token types.

### Session flow

1. Generate `code_verifier` (43–128 chars, unreserved charset) and `code_challenge` = Base64URL(SHA-256(verifier)) with no padding. Method is always `S256`, never `plain`.
2. Generate a high-entropy `state`. Bind it to the in-flight session (memory). Reject callbacks whose `state` does not match.
3. Bind the callback listener (loopback on `127.0.0.1:0`, or deep-link handler).
4. Build the auth URL with `client_id`, exact `redirect_uri`, `response_type=code`, Gmail scopes, `code_challenge`, `code_challenge_method=S256`, `state`, `access_type=offline`, and `prompt=consent` on first login so Google returns a refresh token.
5. Open that URL with `tauri-plugin-opener`.
6. On success, POST to `https://oauth2.googleapis.com/token` with `grant_type=authorization_code`, `code`, `code_verifier`, the **same** `redirect_uri`, `client_id`, and `client_secret` when present.
7. Store refresh token in keyring keyed by service id + account email. Drop the verifier and authorization code.
8. Return `{ email, name }` (from `userinfo` or ID token) to the frontend — not tokens.
9. On later Gmail calls, if the access token is missing or near expiry, refresh from keyring in Rust. If Google returns `invalid_grant`, delete the keyring entry and surface "re-login required".

### Gmail scopes

Ask for the **least** Gmail scope that matches the feature. Combine with `openid email profile` when the UI needs identity.

| Need | Scope |
|---|---|
| Read mail | `https://www.googleapis.com/auth/gmail.readonly` |
| Send only | `https://www.googleapis.com/auth/gmail.send` |
| Labels / modify | `https://www.googleapis.com/auth/gmail.modify` |
| Compose drafts | `https://www.googleapis.com/auth/gmail.compose` |

Reject `https://mail.google.com/` unless the user explicitly needs IMAP/full mailbox control. Other Google APIs (Drive, Calendar) reuse this same flow; only the scope list and the API host change.

### Tauri capabilities and crates

`src-tauri/capabilities/default.json` must allow `opener:default` (and `deep-link:default` only if using custom URI). Do not grant the WebView arbitrary HTTP to Google token endpoints.

Cargo: `tauri`, `tauri-plugin-opener`, `keyring`, `reqwest` (json + rustls), `tokio`, `serde`, `serde_json`, `sha2`, `base64`, `rand`, `url`. Add `tauri-plugin-deep-link` and `tauri-plugin-single-instance` (feature `deep-link`) only for the custom-URI path.

Prefer a small loopback in `loopback.rs` owned by this app over `tauri-plugin-oauth` if that plugin would emit the raw callback URL into JavaScript. If the plugin is used, the callback must stay in Rust.

### Frontend contract

TypeScript only calls:

- `invoke('start_login')` → `{ email, name }`
- `invoke('check_session')` → `{ email, name } | null`
- `invoke('logout')`
- `invoke('gmail_request', { op, payload })` → operation result

No OAuth URL construction, no PKCE, no token storage in JS.

## Audit mode

Read `references/audit-rules.md` and apply every rule. Output a findings list: severity, file, rule id, evidence, required fix. Do not "note and continue" on WebView login or frontend token storage — those are failures.

## Troubleshooting

For `invalid_request`, `disallowed_useragent`, port collisions, missing refresh tokens, or macOS silent deep-link drops, read `references/troubleshooting.md` before inventing a new architecture.

## What not to do

- Do not implement implicit flow (`response_type=token`) or embed Google GIS in the WebView.
- Do not log `code`, `code_verifier`, access tokens, or refresh tokens.
- Do not bind the loopback server to `0.0.0.0`.
- Do not hardcode a callback port (`8080`, `3000`, `1420`).
- Do not copy `redirect_uri` by reconstructing it; store the exact string used on `/auth`.
- Do not put Gmail JSON-RPC in the frontend with a Bearer token passed as a command argument.
