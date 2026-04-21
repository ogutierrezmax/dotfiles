# Curso: Dominando seu .bashrc no Repositório de Dotfiles

Bem-vindo ao guia prático para incluir e profissionalizar suas configurações de Bash no seu repositório de dotfiles. Este curso vai te levar do "arquivo bagunçado na home" para uma "arquitetura modular e automatizada".

---

## Módulo 1: O Despertar (Por que gerenciar o .bashrc?)

O `.bashrc` é o cérebro do seu terminal Bash. Nele vivem seus aliases, variáveis de ambiente e funções. 
**O problema:** Quando você formata o PC ou muda de emprego, perde tudo.
**A solução:** Versionar este arquivo no seu repositório `dotfiles`.

### Exercício 1: Localização
Abra seu terminal e verifique se você já tem um `.bashrc` e para onde ele aponta:
```bash
ls -la ~ | grep .bashrc
```

---

## Módulo 2: O Sequestro (Movendo o arquivo para o repositório)

Não queremos apenas uma *cópia* no Git. Queremos que o arquivo *real* viva no repositório e que o sistema apenas o "enxergue" na pasta Home.

### Passo a Passo:
1. Mova o arquivo da sua Home para a pasta `data/` do seu repositório:
   ```bash
   mv ~/.bashrc ~/dotfiles/data/
   ```
2. Adicione o nome `.bashrc` no arquivo `config/dotfile-names.list` para que seu script de menu saiba que ele deve ser linkado.

---

## Módulo 3: A Mágica dos Links (Symlinks)

Agora que o arquivo está no repositório, o Bash não vai encontrá-lo (ele procura em `~/.bashrc`). Precisamos criar um **Link Simbólico**.

Se você usar o seu script `dotfiles-menu.sh`, ele fará isso por você. Mas por trás das cenas, o comando é:
```bash
ln -sf ~/dotfiles/data/.bashrc ~/.bashrc
```
*Dica: O `-f` (force) é importante para remover o arquivo antigo se ele existir.*

---

## Módulo 4: Modularizar para Conquistar

Ter um único arquivo de 500 linhas é um pesadelo. Vamos aplicar a **Arquitetura Modular**.

### A ideia:
Em vez de colocar tudo no `.bashrc`, ele vai apenas "chamar" outros arquivos menores.

1. No seu `.bashrc` (dentro do repo), adicione este código:
   ```bash
   # Carrega módulos da pasta ~/.bashrc.d/
   if [ -d "$HOME/.bashrc.d" ]; then
       for config in "$HOME/.bashrc.d/"*.sh; do
           [ -r "$config" ] && source "$config"
       done
   fi
   ```
2. Crie a pasta `data/.bashrc.d/` no seu repo e adicione-a também ao `dotfile-names.list`.

---

## Módulo 5: Performance (O Terminal Veloz)

Se o seu terminal demora para abrir, você está fazendo algo errado.

### Regra de Ouro:
**Evite comandos externos no startup.**
- **Ruim:** `export IP=$(curl -s ifconfig.me)` (Lento, depende de internet).
- **Bom:** Use aliases para coisas que você não precisa o tempo todo.
- **Lazy Loading:** Se você usa `nvm` ou `rbenv`, procure por "lazy load" scripts para que eles só carreguem quando você realmente digitar `node` ou `ruby`.

---

## Módulo 6: O Toque Profissional (Segredos e Localização)

Algumas coisas você **não** quer no Git (como o token do GitHub ou o nome da sua impressora de casa).

### A técnica do `.local`:
No final do seu `.bashrc`, adicione:
```bash
# Carrega configurações locais que NÃO estão no Git
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
```
Adicione `.bashrc.local` ao seu `.gitignore`. Agora você tem um lugar seguro para segredos!

---

## Desafio Final: A Grande Integração

1. Organize seus aliases em `data/.bashrc.d/aliases.sh`.
2. Mova suas variáveis de ambiente para `data/.bashrc.d/env.sh`.
3. Use o `dotfiles-menu.sh` para instalar tudo.
4. Rode `bash` e veja se tudo funciona!

---
*Próximo passo: Leia o arquivo `docs/bashrc_best_practices.md` para se aprofundar nos detalhes técnicos!*
