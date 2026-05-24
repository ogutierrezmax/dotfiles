# Exemplos de Padrões Factorio 2.0

## 1. Botão Relativo em Interface de Entidade
Útil para adicionar controles específicos a uma máquina.

```lua
script.on_event(defines.events.on_gui_opened, function(event)
    local player = game.get_player(event.player_index)
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Define onde o painel vai "grudar"
    local anchor = {
        gui = defines.relative_gui_type.assembling_machine_gui,
        position = defines.relative_gui_position.right
    }

    local panel = player.gui.relative.add{
        type = "frame",
        name = "meu_painel",
        anchor = anchor
    }
    panel.add{type = "button", name = "btn_acao", caption = "Ação"}
end)
```

## 2. Monitoramento de Status (Falta de Item)
Como detectar se uma máquina parou por falta de recurso.

```lua
local function check_status(entity)
    local status = entity.status
    return status == defines.entity_status.item_ingredient_shortage or 
           status == defines.entity_status.missing_item or
           status == defines.entity_status.waiting_for_source_items
end
```

## 3. Uso de Storage (Persistência)
Padrão 2.0 para salvar dados entre sessões.

```lua
script.on_init(function()
    storage.minha_lista = storage.minha_lista or {}
end)

-- Acessando depois
table.insert(storage.minha_lista, {id = 123})
```
