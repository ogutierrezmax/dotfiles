# Google Cloud Console (Desktop + Gmail)

Configure this before writing Tauri code. Wrong client type is the usual reason a "correct" PKCE implementation still fails.

## Project and APIs

1. Create or select a Google Cloud project.
2. Enable **Gmail API**. Enable **People API** or use `https://openidconnect.googleapis.com/v1/userinfo` if you only need email/name.
3. Configure the OAuth consent screen (External + Testing is fine while iterating). Add the developer Google account as a test user or Google will block the consent screen.
4. Create credentials → OAuth client ID → application type **Desktop app**.

Copy `client_id`. If a `client_secret` is shown, store it for the Rust token POST (see SKILL.md). Do not create a second "Web application" client for the same desktop binary.

## Redirect URIs

**Loopback (Desktop client):** Google accepts `http://127.0.0.1:<port>/...` without listing every ephemeral port. Still use a stable path such as `/callback`. Use `127.0.0.1`, not `localhost`.

**Custom scheme:** Register a reverse-DNS scheme you control, e.g. `com.example.app:/oauth2redirect` or `com.example.app://oauth2redirect`. The value in Console, `tauri.conf.json`, and both OAuth requests must match.

## Installed-app auth URL shape

```
https://accounts.google.com/o/oauth2/v2/auth
  ?client_id=...
  &redirect_uri=http://127.0.0.1:PORT/callback
  &response_type=code
  &scope=openid%20email%20profile%20https://www.googleapis.com/auth/gmail.readonly
  &code_challenge=...
  &code_challenge_method=S256
  &state=...
  &access_type=offline
  &prompt=consent
```

`access_type=offline` and a consent prompt are required to receive a refresh token on first grant. Subsequent logins without `prompt=consent` may omit the refresh token if one was already issued.

## Token endpoint

`POST https://oauth2.googleapis.com/token`  
`Content-Type: application/x-www-form-urlencoded`

Authorization-code exchange: `code`, `client_id`, `client_secret` (if issued), `redirect_uri`, `grant_type=authorization_code`, `code_verifier`.

Refresh: `refresh_token`, `client_id`, `client_secret` (if issued), `grant_type=refresh_token`.

## Restricted Gmail scopes

Gmail scopes are sensitive. Testing users work immediately. Production (External + restricted scopes) needs Google verification. Do not promise unrestricted Gmail access in the UI until that process is planned.

Official docs:

- https://developers.google.com/identity/protocols/oauth2/native-app
- https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration
- https://developers.google.com/gmail/api/auth/scopes
