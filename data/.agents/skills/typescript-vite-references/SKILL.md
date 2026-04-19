---
name: typescript-vite-references
description: >-
  Configura TypeScript com project references (solution) em projetos Vite/React:
  evita TS6310/TS6306 (composite vs noEmit), define emitDeclarationOnly com outDir
  seguro, e scripts tsc -b --noEmit. Use ao ver "referenced project may not disable
  emit", "pode não desabilitar a emissão", tsconfig com files vazio + references,
  ou ao alinhar typecheck CI com Vite.
---

# TypeScript + Vite: project references

## Regra principal

Se um `tsconfig` é **referenciado** por outro (`references` no raiz) e usa **`"composite": true`**, ele **não pode** ter **`"noEmit": true`**. O TypeScript exige emissão (no mínimo declarações) para compor o grafo — erro típico **TS6310** (e mensagens como “o projeto referenciado pode não desabilitar a emissão”).

## Padrão recomendado (app + node, Vite)

### `tsconfig.json` (raiz, solution)

- `"files": []`
- Somente `"references"` para `tsconfig.app.json` e `tsconfig.node.json`
- **Não** colocar `"include": ["src"]` no raiz: mistura com references gera TS6305/TS6306 inconsistentes.

### `tsconfig.app.json` (código em `src/`)

- Manter `"composite": true`
- **Remover** `"noEmit": true`
- Adicionar:
  - `"declaration": true`
  - `"emitDeclarationOnly": true`
  - `"outDir": "node_modules/.tmp/tsc-app"` (ou outro cache; **evitar** o mesmo `outDir` do `vite build`, normalmente `dist`)

### `tsconfig.node.json` (`vite.config.ts`, scripts Node)

- Mesma ideia: `composite`, `declaration`, `emitDeclarationOnly`, sem `noEmit`
- `"rootDir": "."` quando o include é só arquivos na raiz do pacote
- `"outDir": "node_modules/.tmp/tsc-node"`

`node_modules/` costuma já estar no `.gitignore`; artefatos `.d.ts` ficam fora do bundle do Vite.

## Armadilha: `tsc --noEmit` na raiz

Com o raiz só com `files: []` + `references`, **`npx tsc --noEmit` (sem `-b`, sem `-p`)** costuma **sair 0** sem checar `src/`, porque o programa do projeto raiz não inclui fontes.

**Typecheck real do monólito TS:**

```bash
npx tsc -b --noEmit
```

Ou só o app:

```bash
npx tsc --noEmit -p tsconfig.app.json
```

## Scripts npm sugeridos

```json
"typecheck": "tsc -b --noEmit",
"typecheck:watch": "tsc -b --noEmit --watch"
```

Build que só valida tipos antes do Vite (sem depender de emitir `.d.ts` no CI):

```json
"build": "tsc -b --noEmit && vite build"
```

(Se preferir manter `tsc -b` emitindo declarações para incremental local, use `tsc -b && vite build` em vez disso.)

## Checklist rápido

- [ ] Referenciados com `composite: true` **sem** `noEmit: true`
- [ ] `emitDeclarationOnly` + `declaration` + `outDir` em cache (não `dist`)
- [ ] Raiz solution sem `include` duplicado de `src`
- [ ] Typecheck usa `tsc -b --noEmit`, não só `tsc --noEmit` na raiz

## Alternativa (sem references)

Se **não** precisar de solution/references: remover `references` do raiz e `composite` dos filhos; um único `tsconfig` com `"noEmit": true` e `include` adequado. Perde-se o split explícito app/node que o template Vite costuma usar.
