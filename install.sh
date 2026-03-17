#!/usr/bin/env bash

# Pasta onde os dotfiles estão
DOTFILES_DIR=~/dotfiles

# Lista de arquivos para linkar (separados por espaço)
files="gitconfig"

echo "AVISO: Este script vai SOBRESCREVER os arquivos existentes em ~ (ex.: ~/.gitconfig)"
echo "       se já existirem. Os arquivos atuais serão substituídos por links simbólicos."
echo ""
read -p "Deseja continuar? (s/n): " -r resposta
if [[ ! "$resposta" =~ ^[sS]$ ]]; then
    echo "Instalação cancelada."
    exit 1
fi
echo ""

for file in $files; do
    echo "Criando link simbólico para $file em ~"
    ln -sf $DOTFILES_DIR/$file ~/.$file
done

echo "Configuração concluída!"