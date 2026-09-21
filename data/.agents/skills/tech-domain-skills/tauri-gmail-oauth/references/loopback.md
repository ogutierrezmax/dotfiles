# Loopback redirect (default desktop path)

RFC 8252 and Google native-app docs recommend a local HTTP listener on the loopback interface for desktop OS (not UWP).

## Why ephemeral port 0

A fixed port (`8080`, `3000`, `1420`) fails with `Address Already in Use` whenever another process holds it. Binding `127.0.0.1:0` lets the OS pick a free port. Read the assigned port from the listener and interpolate it into `redirect_uri` **once**. Reuse that exact string on the token POST.

Bind IPv4 loopback only (`127.0.0.1`). Do not bind `0.0.0.0`. Do not silently fall back to `localhost` — Google treats `http://127.0.0.1:PORT/callback` and `http://localhost:PORT/callback` as different URIs.

## Lifecycle

1. Start the listener before opening the browser.
2. Apply a timeout (e.g. 3–5 minutes). On timeout, shut down and return a typed error to `start_login`.
3. Accept one request. Parse `code` and `state` from the query. Reject missing `code`, OAuth `error=`, or `state` mismatch.
4. Respond with a small HTML page: authentication finished, user may close the tab. Then drop the listener so the port is not left open.
5. Exchange the code in Rust. Never emit the full callback URL to the WebView.

The loopback port is unauthenticated. `state` + PKCE are what stop another local process from completing the login.

## Sketch (ownership stays in Rust)

```rust
let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await?;
let port = listener.local_addr()?.port();
let redirect_uri = format!("http://127.0.0.1:{port}/callback");
// open auth URL with opener, then accept one HTTP request on listener
```

A hand-rolled HTTP/1.1 read on the accepted stream is enough for a single GET. A full web framework is unnecessary.

## After Google redirects

Respond `200` with `Content-Type: text/html; charset=utf-8` and a short message. Then POST `/token` with the stored `redirect_uri`, `code_verifier`, and `client_secret` if present.

## Plugin note

`tauri-plugin-oauth` also spawns a localhost server. Use it only if the URL callback is handled in Rust and you still generate PKCE/`state` yourself. Do not use its JS `onUrl` as the place that talks to Google's token endpoint.
