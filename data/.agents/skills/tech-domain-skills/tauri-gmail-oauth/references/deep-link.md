# Custom URI (deep link) redirect

Google allows a custom scheme for Desktop clients. Prefer this only when the product must complete login after a cold start, or when the user already standardized on deep links.

Loopback is still the better default for `tauri dev`, especially on macOS.

## Tauri v2 wiring

`tauri.conf.json`:

```json
{
  "plugins": {
    "deep-link": {
      "desktop": {
        "schemes": ["com.example.app"]
      }
    }
  }
}
```

The `redirect_uri` sent to Google must be the full URI you will actually receive, including path, e.g. `com.example.app://oauth2redirect`. Match Console, config, `/auth`, and `/token`.

Capabilities: `deep-link:default` plus `opener:default`.

Register `tauri-plugin-deep-link`. On Linux and Windows, register `tauri-plugin-single-instance` **first**, with the `deep-link` feature, so a second process started by the browser forwards argv to the running instance instead of opening a duplicate window.

```rust
#[cfg(desktop)]
{
    builder = builder.plugin(tauri_plugin_single_instance::init(|_app, argv, _cwd| {
        // deep-link plugin already emits on_open_url for configured schemes
        let _ = argv;
    }));
}
builder = builder.plugin(tauri_plugin_deep_link::init());
```

Handle both `get_current()` at startup (app launched by the redirect) and `on_open_url` while running. Extract `code` and `state`, then exchange tokens in Rust — same as loopback.

## Platform traps

- **macOS:** schemes are registered from the bundled `Info.plist`. `tauri dev` is not a full `.app`; callbacks fail silently. Test custom URI on a packaged app under `/Applications`, or use loopback during development.
- **Linux:** the installed `.desktop` file must pass the URL (`Exec=... %u`). `register_all()` in release can shadow the package handler. Follow `tauri-deep-link-linux` instead of improvising.
- **Windows/Linux:** without single-instance, the user sees a second window and the first session never gets the `code`.
- **Scheme collisions:** any other app can register the same protocol. PKCE + `state` still apply. Use a reverse-DNS scheme you control, not `oauth` or `gmail`.

## Security

The OS can start the app with a fabricated URL. Verify:

- scheme and path match the configured redirect
- `state` matches the in-flight login (or a short-lived pending login started before the browser opened)
- `code` is single-use and exchanged immediately

Do not parse tokens from a URL fragment. This flow is authorization code, not implicit.
