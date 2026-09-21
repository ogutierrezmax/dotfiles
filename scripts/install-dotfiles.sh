#!/usr/bin/env bash
set -euo pipefail

# SECURITY NOTE: Always audit shell scripts before execution, especially those 
# generated or modified by LLMs. Ensure you understand what each command does.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/dotfiles-lib.sh
source "${SCRIPT_DIR}/dotfiles-lib.sh"

echo "AVISO: Este script vai SOBRESCREVER os arquivos existentes em ~ (ex.: ~/.gitconfig)"
echo "       se já existirem. Os arquivos atuais serão substituídos por links simbólicos."
echo ""
read -p "Deseja continuar? (s/n): " -r resposta
if [[ ! "$resposta" =~ ^[sS]$ ]]; then
    echo "Instalação cancelada."
    exit 1
fi
echo ""

dotfiles_link_from_dotfile_names

# Bridge de skills de IA → acervo central ~/.agents/skills (config/agent-skills-bridge.list).
# Cria os symlinks por-skill nas ferramentas que não leem ~/.agents/skills nativamente
# (Claude Code, Devin, Antigravity; espelhos opcionais em Cursor/Gemini).
if [[ -x "${SCRIPT_DIR}/install-agent-skills-bridge.sh" ]]; then
    "${SCRIPT_DIR}/install-agent-skills-bridge.sh"
fi

# Perfis OpenCode → symlinks por-arquivo para a fonte única
# (config/opencode-profiles.list; preserva cli.json/service.json locais).
if [[ -x "${SCRIPT_DIR}/install-opencode-profiles.sh" ]]; then
    "${SCRIPT_DIR}/install-opencode-profiles.sh"
fi

echo "Configuração concluída!"
