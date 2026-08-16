---
name: "tauri-deep-link-linux"
description: "Diagnostica e corrige deep links que não funcionam em apps Tauri 2 no Linux. Detecta automaticamente: (1) template .desktop sem %u no Exec, (2) register_all() criando desktop files de dev que sobrescrevem os do sistema, (3) mime handler apontando para binário errado. Use quando deep links Tauri falham no Linux, quando OAuth/login não conclui após redirect do browser, quando xdg-open não abre o app, ou ao configurar deep links pela primeira vez em qualquer projeto Tauri."
---

# Tauri Deep Link Fix (Linux)

Resolve silenciousamente deep links que não funcionam em apps Tauri 2 no Linux. Três problemas causam falha, frequentemente combinados.

## Limitações

- **deb/rpm:** Esta skill cobre distribuição via deb e rpm (ambos usam o mesmo template `.desktop`).
- **AppImage:** O `register_all()` é essencial para AppImage — sem ele, deep links não funcionam. **Não** aplique o Fix 2 se distribuir via AppImage. Considere feature flags se precisar de suporte a ambos.
- **macOS/Windows:** Deep links nestes sistemas usam mecanismos completamente diferentes. Esta skill é Linux-only.

## Diagnóstico

Antes de qualquer fix, executar os comandos abaixo para detectar qual(is) problema(s) existem. Todos os valores devem ser extraídos do projeto, nunca hardcoded.

### 1. Extrair parâmetros do projeto

```bash
# Scheme configurado (ex: "alfocards", "meuapp", "vibe")
grep -o '"schemes":\s*\["[^"]*"' src-tauri/tauri.conf.json

# Nome do produto (para desktop file)
grep '"productName"' src-tauri/tauri.conf.json | head -1

# Nome do binário (para desktop file de dev)
grep '^name' src-tauri/Cargo.toml | head -1
```

### 2. Verificar handler atual

```bash
# Qual desktop file está registrado como handler?
xdg-mime query default x-scheme-handler/{scheme}
# Esperado: {AppName}.desktop (o instalado pelo dpkg)
# Problema: {bin}-handler.desktop (criado por register_all em dev)
```

### 3. Verificar %u no desktop file

```bash
# Desktop file do sistema (instalado pelo dpkg)
cat /usr/share/applications/{AppName}.desktop 2>/dev/null | grep "Exec="
# Problema: Exec={bin} (sem %u)
# OK: Exec={bin} %u
```

### 4. Verificar desktop file de dev

```bash
# Desktop file criado por register_all durante dev mode
ls ~/.local/share/applications/{bin}-handler.desktop 2>/dev/null
# Se existe → register_all() está sobrescrevendo o handler do sistema
```

### 5. Verificar register_all() no lib.rs

```bash
grep -A3 "register_all" src-tauri/src/lib.rs
# Problema: #[cfg(any(windows, target_os = "linux"))]
# OK: #[cfg(debug_assertions)]
```

### 6. Verificar se desktopTemplate já está configurado

```bash
grep -A3 "desktopTemplate" src-tauri/tauri.conf.json 2>/dev/null
# Se não existe → template padrão do Tauri (sem %u)
```

## Fix 1: Template .desktop com %u

**Problema:** O template padrão do Tauri gera `Exec={bin}` sem `%u`. Sem `%u`, o desktop environment não passa a URL do deep link como argumento quando o browser redireciona.

**Por quê:** O `%u` é o placeholder do freedesktop Desktop Entry Spec para "uma URL". Sem ele, `xdg-open alfocards://auth` lança o app mas não passa a URL.

### Criar template

Criar `{project}/src-tauri/linux/deep-link.desktop.hbs`:

Copiar o conteúdo de `references/template.desktop.hbs` (neste diretório da skill).

### Referenciar em tauri.conf.json

Adicionar dentro de `bundle`:

```json
"linux": {
  "deb": {
    "desktopTemplate": "./linux/deep-link.desktop.hbs"
  }
}
```

**Nota:** O `desktopTemplate` está em `bundle.linux.deb`, não `bundle.deb`. O template é compartilhado entre deb e RPM — o resultado afeta ambos os bundles.

### Validar

```bash
npm run tauri build
# Extrair desktop file do .deb gerado e verificar %u:
tar -xOzf src-tauri/target/release/bundle/deb/*.deb data.tar.gz | \
  tar -xzO ./usr/share/applications/{AppName}.desktop
# Confirmar: Exec={bin} %u
```

## Fix 2: register_all() apenas em debug

**Problema:** `register_all()` cria `~/.local/share/applications/{bin}-handler.desktop` apontando para o binário corrente. Em release (dpkg), esse arquivo sobrescreve o desktop file do sistema porque user-local tem prioridade sobre system-level na spec XDG.

**⚠️ AppImage:** Não aplique este fix se distribuir via AppImage. O AppImage precisa de `register_all()` em runtime porque não instala desktop file.

### Mudar em src-tauri/src/lib.rs

De:
```rust
#[cfg(any(windows, target_os = "linux"))]
{
    app.deep_link().register_all()?;
}
```

Para:
```rust
#[cfg(debug_assertions)]
{
    use tauri_plugin_deep_link::DeepLinkExt;
    app.deep_link().register_all()?;
}
```

Mover o `use` para dentro do bloco `#[cfg(debug_assertions)]` para evitar warning de import não utilizado em release.

### Por que funciona

- **Dev mode:** `debug_assertions` é true → `register_all()` rota → deep links funcionam durante desenvolvimento
- **Release (dpkg):** `debug_assertions` é false → `register_all()` não rota → desktop file do dpkg permanece intacto

## Fix 3: Cleanup pós-install

**Problema:** Mesmo com os Fixes 1 e 2, desktop files de dev de sessões anteriores podem persistir.

### Adicionar ao build-and-install.sh

Após o `sudo dpkg -i`:

```bash
echo "Limpando desktop files de deep-link de dev..."
rm -f ~/.local/share/applications/{bin}-handler.desktop
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

echo "Registrando mime handler para deep links..."
xdg-mime default {AppName}.desktop x-scheme-handler/{scheme}
```

Substituir `{bin}` pelo nome do binário (de `Cargo.toml`) e `{AppName}` pelo nome do produto (de `tauri.conf.json`).

## Cadeia causal

```
Browser redireciona para {scheme}://auth#tokens
    ↓
OS consulta xdg-mime → encontra desktop file
    ↓
Desktop file Exec= NÃO tem %u → URL não passada como arg
    ↓
App inicia SEM a URL → deep link perdido
    ↓
Login não conclui silenciosamente
```

Com os 3 fixes aplicados:
```
Browser redireciona para {scheme}://auth#tokens
    ↓
OS consulta xdg-mime → encontra {AppName}.desktop (correto)
    ↓
Desktop file Exec={bin} %u → URL passada como arg
    ↓
App recebe URL → processa tokens → login conclui
```

## Referências

- [Tauri Deep Linking](https://v2.tauri.app/plugin/deep-linking/) — documentação oficial do plugin
- [Issue #5176](https://github.com/tauri-apps/tauri/issues/5176) — feature request para desktopTemplate customizável
- [Issue #10570](https://github.com/tauri-apps/tauri/issues/10570) — bug report: deep links broken on Linux
- [Freedesktop Desktop Entry Spec](https://specifications.freedesktop.org/desktop-entry-spec/latest/) — %u/%U placeholders
- [Template padrão do Tauri](https://github.com/tauri-apps/tauri/blob/dev/crates/tauri-bundler/src/bundle/linux/freedesktop/main.desktop) — template que gera Exec sem %u
