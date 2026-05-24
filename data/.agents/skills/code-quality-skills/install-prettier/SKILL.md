---
name: "install-prettier"
description: "Install and configure Prettier in JavaScript/TypeScript projects with ESLint integration, VS Code auto-format-on-save, and pre-commit hooks. Use when setting up a new project, configuring code formatting, or when the user mentions Prettier, formatter, or formatting setup."
---

# Install Prettier

## Instructions

### 1. Install locally (devDependency)

```bash
npm install --save-dev --save-exact prettier
```

Use `--save-exact` to pin the exact version and avoid formatting inconsistencies across the team.

### 2. Create config files

**`.prettierrc`**:

```json
{
  "trailingComma": "es5",
  "tabWidth": 2,
  "semi": true,
  "singleQuote": true,
  "printWidth": 100,
  "bracketSpacing": true
}
```

**`.prettierignore`**:

```
node_modules
build
dist
coverage
*.min.js
package-lock.json
pnpm-lock.yaml
yarn.lock
```

### 3. Integrate with ESLint

Install the conflict-disabling plugin:

```bash
npm install --save-dev eslint-config-prettier
```

Add `"prettier"` as the **last** entry in the `extends` array of your ESLint config.

### 4. VS Code settings

Create `.vscode/settings.json`:

```json
{
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "[javascript]": { "editor.formatOnSave": true },
  "[typescript]": { "editor.formatOnSave": true },
  "[json]": { "editor.formatOnSave": true },
  "[html]": { "editor.formatOnSave": true },
  "[css]": { "editor.formatOnSave": true }
}
```

### 5. Pre-commit hooks

```bash
npx husky-init && npm install
npm install --save-dev lint-staged
```

Add to `package.json`:

```json
"lint-staged": {
  "*.{js,ts,jsx,tsx,json,css,md}": "prettier --write"
}
```

### 6. package.json scripts

```json
"scripts": {
  "format": "prettier --write \"src/**/*.+(js|ts|json|css|md)\"",
  "format:check": "prettier --check \"src/**/*.+(js|ts|json|css|md)\""
}
```
