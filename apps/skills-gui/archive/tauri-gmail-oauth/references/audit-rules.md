# Audit rules (fail closed)

Scan `src-tauri` and the frontend. Cite file and symbol. Severity: **fail** blocks merge; **warn** needs a documented reason.

## A1 — External user-agent (fail)

Search frontend and Rust for login against `accounts.google.com` via:

- `WebviewWindow`, `WebviewWindowBuilder`, extra Tauri windows loading Google
- `<iframe>`
- `window.open`
- `webview.eval` navigating to the auth URL

Required: `tauri-plugin-opener` (or `open` crate / OS shell) on the **authorization** URL only. Gmail API and token HTTP stay in `reqwest`.

## A2 — Tokens never in the WebView (fail)

Search `.ts`, `.tsx`, `.js`, `.vue`, `.svelte` for `localStorage`, `sessionStorage`, `indexedDB`, cookies, or plaintext writes involving `refresh_token`, `access_token`, `id_token`, or `code_verifier`.

Also fail if a Tauri command returns those fields, or if `emit`/`listen` sends the raw callback URL to JS for token exchange.

Required: `keyring` on Rust; access token only in Rust memory; frontend session type is identity (`email`, `name`) plus app state.

## A3 — PKCE integrity (fail)

Authorization URL must include `code_challenge` and `code_challenge_method=S256`.

Token POST body must include `code_verifier` and the same `redirect_uri` string used on `/auth` (same host, port, path, trailing slash).

Fail `plain` PKCE. Fail reconstructed redirect URIs (e.g. swapping `localhost` / `127.0.0.1` between steps).

## A4 — Listener and concurrency (fail / warn)

- **Fail** if loopback binds a hardcoded port.
- **Fail** if the listener binds `0.0.0.0`.
- **Fail** (custom URI on desktop) if `tauri-plugin-single-instance` is missing on Windows/Linux.
- **Warn** if there is no login timeout on the loopback accept.
- **Warn** if `register_all()` runs in Linux release builds (see `tauri-deep-link-linux`).

## A5 — Client type and scopes (fail / warn)

- **Fail** if comments or config show a **Web application** client used with this desktop binary as the only client.
- **Warn** if `https://mail.google.com/` is requested without an explicit IMAP/full-access requirement.
- **Warn** if `access_type=offline` is missing (no refresh token).
- **Warn** if `client_secret` is omitted on `/token` while a Desktop secret exists in env/config — Google often rejects secretless exchange.

## A6 — Hygiene (fail / warn)

- **Fail** if tokens, codes, or verifiers are logged (`println!`, `dbg!`, `console.log`).
- **Warn** if Gmail requests are made from the frontend with a token argument.
- **Warn** if command names or modules are not English (`iniciar_login`, etc.) — rename to `start_login`.

## Report shape

```
## OAuth audit
- [fail|warn] A# — title
  File: path:line
  Evidence: ...
  Fix: ...
```

If any **fail** exists, do not describe the implementation as production-ready.
