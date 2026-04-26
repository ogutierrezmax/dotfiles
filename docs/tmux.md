# 🪟 Tmux (Terminal Multiplexer)

> Configuração modular para persistência de sessões e produtividade no terminal.

Este documento detalha a configuração atual do `tmux`, que utiliza o **TPM (Tmux Plugin Manager)** para gerenciar extensões de automação e persistência.

## 🛠 Tech Stack
- **Multiplexer**: tmux
- **Gerenciador de Plugins**: [TPM](https://github.com/tmux-plugins/tpm)
- **Persistência**: `tmux-resurrect` & `tmux-continuum`

## ⚡ Configuração Atual (`~/.tmux.conf`)

A configuração está focada em manter o ambiente de trabalho persistente mesmo após reinicializações do sistema.

```tmux
# Lista de plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Configurações do Continuum
set -g @continuum-restore 'on'    # Restaura automaticamente a última sessão salva
set -g @continuum-save-interval '15' # Salva a cada 15 minutos

# Inicializa o gerenciador de plugins (mantenha esta linha no final)
run '~/.tmux/plugins/tpm/tpm'
```

## 🗺 Estrutura de Arquivos
- `~/.tmux.conf`: Arquivo principal de configuração.
- `~/.tmux/plugins/`: Diretório onde o TPM instala os plugins.

## 🚀 Como instalar (Manual)

1. **Instale o TPM**:
   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```
2. **Configure o `.tmux.conf`**:
   Copie o conteúdo acima para o seu arquivo `~/.tmux.conf`.
3. **Instale os plugins**:
   Abra o tmux e pressione `prefix` + `I` (Shift + i) para baixar e instalar os plugins listados.

## 📖 Plugins Utilizados

### [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
Permite salvar e restaurar o ambiente do tmux manualmente.
- `prefix` + `Ctrl-s`: Salva.
- `prefix` + `Ctrl-r`: Restaura.

### [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
Automatiza o `tmux-resurrect`.
- Salva o ambiente a cada 15 minutos.
- Restaura automaticamente ao iniciar o tmux.

---
*Este documento serve como base para o futuro versionamento do tmux nestes dotfiles.*
