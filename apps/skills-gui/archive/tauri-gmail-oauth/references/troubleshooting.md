# Recurring failures

| Symptom | Likely cause | Fix |
|---|---|---|
| HTTP 400 `invalid_request` on `/token` | `redirect_uri` differs from `/auth` (port, `localhost` vs `127.0.0.1`, path, slash) | Persist the exact URI from the session; send it unchanged |
| `invalid_request` / `client_secret is missing` | Desktop client secret omitted despite Console issuing one | Send `client_secret` on `/token` and refresh; keep PKCE |
| `invalid_grant` | Code reused, verifier wrong, or clock/`code` expired | One exchange only; keep verifier in memory until that POST |
| Google screen: app/browser not secure, or `disallowed_useragent` | Auth page opened in Tauri WebView / iframe / secondary webview | Open with `tauri-plugin-opener` |
| `Address Already in Use` | Hardcoded loopback port | Bind `127.0.0.1:0` |
| Consent works, no `refresh_token` | Missing `access_type=offline` or Google already issued a token and `prompt` was not `consent` | Add both on first link; store refresh token immediately |
| Second window after callback | Custom URI without single-instance on Windows/Linux | `tauri-plugin-single-instance` with `deep-link` feature, registered first |
| Deep link works nowhere in macOS `tauri dev` | No bundled signed `.app` / Info.plist registration | Use loopback in dev; test custom URI on packaged app |
| Linux: browser opens app but login never finishes | `.desktop` missing `%u`, or `register_all()` stole the handler | Follow `tauri-deep-link-linux` |
| Loopback "deprecated" panic from a blog post | Deprecation is mobile + Chrome app clients | Desktop + `127.0.0.1` remains supported |

When debugging token errors, log status, OAuth `error`, and `error_description` only — never the code, verifier, or tokens.
