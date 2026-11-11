---
name: "factorio-modding"
description: "Fornece expertise em criação e manutenção de mods para Factorio, com foco na API 2.0 (Space Age). Use quando o usuário pedir para criar, depurar ou otimizar mods, lidar com protótipos, eventos ou GUIs do Factorio."
---

# Factorio Modding Expert

Este guia ensina como desenvolver mods robustos para Factorio, especialmente para a versão 2.0+.

## Checklist de Compatibilidade (Sempre checar antes de codificar)
- [ ] **Qual a versão do Factorio do usuário?** (Se for 2.0+, use `storage` e `factorio_version: "2.0"`).
- [ ] **As dependências no `info.json` batem com a versão?** (`base >= 2.0`).
- [ ] **Propriedades de GUI**: `visible`, `caption`, `state`, etc., pertencem ao elemento (ex: `element.visible`), **nunca** ao `element.style`.
- [ ] **Validação de Entidade**: Sempre usar `if not entity or not entity.valid then return end` em eventos.

## Estrutura Básica de um Mod
- **info.json**: Metadados (nome, versão, dependências).
- **data.lua**: Definição de protótipos (itens, entidades, receitas) - roda no carregamento do jogo.
- **control.lua**: Lógica de runtime (eventos, scripts) - roda durante a partida.
- **settings.lua**: Definição de configurações de usuário.
- **locale/**: Traduções em arquivos `.cfg`.

## Mudanças Críticas no Factorio 2.0
- **Storage**: A tabela `global` foi renomeada para `storage`. Use `storage.minha_tabela` para persistência.
- **Version**: `factorio_version` deve ser `"2.0"`.
- **Prototypes**: `game.recipe_prototypes` foi movido para `prototypes.recipe`.
- **Fornalhas**: Fornalhas agora possuem a propriedade `previous_recipe` para persistência visual.

## Melhores Práticas
1. **Performance**: Use `on_nth_tick` em vez de `on_tick` sempre que possível para tarefas periódicas.
2. **Segurança**: Sempre verifique `entity.valid` antes de acessar propriedades de uma entidade.
3. **Persistência**: Guarde apenas o necessário na tabela `storage`. Não guarde referências a objetos da API (como `LuaEntity`), guarde o `unit_number` ou a própria referência se for seguro.
4. **GUI**: Use `player.gui.relative` para interfaces que acompanham janelas de entidades.

## Eventos Comuns
- `defines.events.on_gui_opened`: Quando um jogador abre uma interface.
- `defines.events.on_entity_died`: Quando uma construção é destruída.
- `defines.events.on_player_built_tile`: Quando pisos são colocados.

## Referência Rápida
- [Documentação Oficial (Wiki)](https://wiki.factorio.com/Main_Page)
- [API de Runtime](https://lua-api.factorio.com/latest/)

## Padrões de Robustez (Prevenção de Erros)

### 1. Padrão de Compatibilidade 2.0
Para garantir que o mod carregue e salve dados corretamente no Factorio 2.0:
- Use **`storage`** para persistência de dados (a tabela `global` é obsoleta).
- No `info.json`, defina `"factorio_version": "2.0"` e `"dependencies": ["base >= 2.0"]`.

### 2. Padrão de Manipulação de GUI
Para evitar falhas de runtime na interface:
- **Estado e Controle**: Aplique propriedades de estado (`visible`, `caption`, `state`, `enabled`) diretamente no objeto do elemento (ex: `frame.visible = true`).
- **Aparência**: Use o objeto `.style` apenas para propriedades de layout e design (ex: `frame.style.width = 100`).

### 4. Padrão de Acesso Seguro a Propriedades (pcall)
Para evitar crashes (ex: "LuaEntity doesn't contain key X") ao acessar propriedades que variam entre tipos de entidades:
```lua
local success, value = pcall(function() return entity.recipe end)
if success then
    -- use o value com segurança
end
```

### 5. Padrão de Receitas e Fornalhas (Factorio 2.0+)
Para obter a receita atual ou a última processada em fornalhas/máquinas:
1. Tente `entity.get_recipe()`.
2. Tente a propriedade direta `entity.recipe`.
3. Para fornalhas vazias, use **`entity.previous_recipe`** (nativo do 2.0).
4. Referências globais de receitas: Use **`prototypes.recipe["nome"]`**.

### 6. Deteção de Status de Máquinas
Para monitorar paradas de produção, inclua sempre os seguintes status:
- `defines.entity_status.no_ingredients` (Crucial para fornalhas no 2.0).
- `defines.entity_status.item_ingredient_shortage`.
- `defines.entity_status.waiting_for_source_items`.
