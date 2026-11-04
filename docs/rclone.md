# ☁️ rclone (Google Drive + backup do HD externo)

> Google Drive montado como pasta normal em `~/GoogleDrive`, mais um backup diário e retomável de um HD externo de 1 TB para a nuvem.

O Google não distribui o Drive for Desktop para Linux. A solução aqui é o `rclone`, mas **não** no modo "digitar comando": o mount e o backup rodam como serviços do `systemd --user`, então sobem no login e continuam depois de reiniciar.

---

## 🛠 Tech Stack

| Camada | Peça | Papel |
| :--- | :--- | :--- |
| Credencial | `~/.config/rclone/rclone.conf` | `client_id` + `client_secret` + `refresh_token` (equivale à senha da conta) |
| Motor | `/usr/bin/rclone` (upstream, ≥ 1.70) | fala com a API do Drive: chunks, retry, paralelismo, checksums |
| Orquestração | `systemd --user` | garante que roda no login e retoma o que faltou |
| Interface | Dolphin (`~/GoogleDrive`) + `Rclone UI` opcional | arrastar/colar e painel de transferências |

> **Regra de ouro:** um dono por destino. Dois clientes escrevendo na mesma pasta da nuvem = sobrescrita silenciosa (last-write-wins), porque nenhum deles lê o estado do outro.

---

## 🗺 Arquitetura

```
            ┌──────────────── rclone.conf (600) ────────────────┐
            │ client_id / client_secret / refresh_token         │
            └───────────────────────┬───────────────────────────┘
                                    │
                   ┌────────────────▼─────────────────┐
                   │        /usr/bin/rclone           │
                   └───┬──────────────────────┬───────┘
                       │                      │
        rclone-gdrive.service        rclone-backup.service
        (mount, Type=notify)         (copy, Type=oneshot)
                       │                      │
              ~/GoogleDrive            gdrive:Backup-SanDisk-1TB
              (uso do dia a dia)       (só o timer/HD escrevem aqui)
```

O mount **exclui** `Backup-SanDisk-1TB` (`--exclude="/Backup-SanDisk-1TB/**"`), justamente para que nenhuma cópia de arquivo feita pelo Dolphin caia na pasta que o backup gerencia.

---

## 📦 Arquivos gerenciados

| Arquivo (em `data/`) | Destino em `~` | Função |
| :--- | :--- | :--- |
| `.config/systemd/user/rclone-gdrive.service` | `~/.config/systemd/user/` | monta `gdrive:` em `~/GoogleDrive` |
| `.config/systemd/user/rclone-backup.service` | `~/.config/systemd/user/` | `rclone copy` do HD → Drive (oneshot) |
| `.config/systemd/user/rclone-backup.timer` | `~/.config/systemd/user/` | dispara o backup 1×/dia com `Persistent=true` |

Fora do versionamento (por design):

- `~/.config/rclone/rclone.conf` — **contém segredo**; `.gitignore` cobre.
- `~/GoogleDrive` — criado pelo `ExecStartPre` do mount.
- `~/.cache/rclone` — cache do VFS (8 GB máx.).

---

## ⚙️ Parâmetros que importam

### Mount (`rclone-gdrive.service`)

| Flag | Valor | Por quê |
| :--- | :--- | :--- |
| `--vfs-cache-mode` | `full` | permite escrita/edição sem corromper arquivo; sem isso, salvar por cima quebra |
| `--vfs-cache-max-size` | `8G` | o `/home` desta máquina tem ~26 GB livres — 15 GB de cache era risco de encher o disco |
| `--vfs-cache-max-age` | `24h` | expira cache parado |
| `--dir-cache-time` | `1000h` | evita re-listar o Drive a cada `ls`; invalidado por `--poll-interval` |
| `--poll-interval` | `15s` | mudanças feitas no navegador/celular aparecem em ~15 s no mount |
| `--drive-export-formats` | `docx,xlsx,pptx,pdf,svg` | Docs/Sheets/Slides aparecem como arquivo exportado |

### Backup (`rclone-backup.service`)

| Flag | Por quê |
| :--- | :--- |
| `copy` (não `sync`) | **nunca apaga** no destino. `sync` com HD desmontado apagaria o backup inteiro |
| `ConditionPathIsMountPoint=/mnt/sandisk` | HD fora da tomada → job é **pulado**, não falha nem sobe lixo |
| `--fast-list` | 1 chamada por ~1000 objetos em vez de 1 por pasta (essencial com 1,1 M arquivos) |
| `--drive-stop-on-upload-limit` | para limpo no teto diário (~750 GiB) em vez de erro por arquivo |
| `--create-empty-src-dirs` | preserva pastas vazias |
| `--rc --rc-addr=127.0.0.1:5577 --rc-no-auth` | expõe o progresso ao vivo para o Rclone UI enquanto roda |
| `TimeoutStartSec=0` | sem timeout: 197 GiB levam horas |
| `Persistent=true` (timer) | horário perdido com a máquina desligada é executado no próximo boot |

---

## 🚀 Instalação (máquina nova)

```bash
# 1. binário upstream + checksum (o apt entrega 1.60, de 2022)
./scripts/install-rclone.sh

# 2. conf + OAuth + serviços
$EDITOR config/rclone.conf.example   # cole seu client_id/secret (ou depois, no conf real)
./scripts/setup-rclone.sh
```

O `setup-rclone.sh` é idempotente e aceita:

- `--status` — read-only: versão, symlinks dos 3 units, permissões do conf, token e estado do mount/timer
- `--dry-run` — simula tudo, sem escrever nem habilitar nada
- `--reconnect` — força novo OAuth (`rclone config reconnect gdrive:`) mesmo com token válido
- `-h` / `--help` — ajuda

Os units não são copiados: o script cria **symlink** de `~/` para `data/` via `dotfiles-lib.sh` (backup em `.bkp/` se já existir arquivo real).

### OAuth: o detalhe que expira em 7 dias

Se o app no Google Auth Platform estiver em **"Em teste"**, o Google invalida o `refresh_token` a cada semana (`invalid_grant`). Publique o app (**"Em produção"**) — uso pessoal com < 100 usuários é isento de verificação.

```bash
rclone config reconnect gdrive:   # refaz o login quando o token cair
```

---

## 🧭 Uso no dia a dia

```bash
systemctl --user status rclone-gdrive          # mount está vivo?
systemctl --user restart rclone-gdrive         # remontar
journalctl --user -u rclone-gdrive -f          # logs ao vivo
fusermount3 -u ~/GoogleDrive                   # desmontar à mão

systemctl --user start rclone-backup           # rodar o backup agora
systemctl --user status rclone-backup          # rodando/último resultado
journalctl --user -u rclone-backup -f          # acompanhar
tail -f ~/backup-sandisk.log                   # log detalhado (1 arquivo + .log.1)
```

`~/GoogleDrive` não é disco local: o arquivo é gravado no cache e sobe ~5 s depois (`--vfs-write-back`). Fechar o Dolphin não interrompe nada — quem escreve é o serviço.

### O que o mount **não** faz

- **Google Docs/Sheets/Slides** chegam como `.docx/.xlsx/.pptx` exportados — não são editáveis por aqui (limitação da API).
- **Sem thumbnail/preview** no Dolphin (FUSE do rclone não expõe `filesystem::use-preview`).
- **Sem resolução de conflito**: editar o mesmo arquivo aqui e no navegador = último que salvou vence.

---

## 🖥 Interface gráfica (opcional)

| Opção | O que é | Combina com o rclone? |
| :--- | :--- | :--- |
| **Dolphin** em `~/GoogleDrive` | o "G:" do Windows | ✅ é o próprio mount |
| **`rclone gui`** | GUI web embutida no binário 1.75+ | ✅ mesmo processo/config |
| **Rclone UI** (`.deb`, `~/.local/opt/rclone-ui`) | app Tauri com fila, tray, agendador e Commander | ✅ lê o mesmo `rclone.conf` |
| Rclone UI **Flatpak** | mesma app, sandbox | ❌ não vê `~/.config/rclone` nem `/mnt` (só `xdg-download`/`xdg-documents`) |
| FreeFileSync / Insync | motores próprios | ❌ stack paralela: OAuth próprio, cache próprio |

Para ver o backup ao vivo: com o `rclone-backup.service` rodando, o Rclone UI conecta em `127.0.0.1:5577` (Remote Control) e mostra arquivos, velocidade e ETA.

Instalação do Rclone UI sem root (o que está nesta máquina):

```bash
curl -fL -o /tmp/rclone-ui.deb https://get.rcloneui.com/linux-deb
mkdir -p ~/.local/opt/rclone-ui/extract
dpkg-deb -x /tmp/rclone-ui.deb ~/.local/opt/rclone-ui/extract
install -Dm755 "$HOME/.local/opt/rclone-ui/extract/usr/bin/Rclone UI" ~/.local/opt/rclone-ui/bin/rclone-ui
cp -r "$HOME/.local/opt/rclone-ui/extract/usr/lib/Rclone UI" ~/.local/opt/rclone-ui/lib/
# wrapper: ~/.local/bin/rclone-ui executa ~/.local/opt/rclone-ui/bin/rclone-ui
```

No primeiro uso o app pede para adicionar um *host*: escolha **Local** — ele passa a usar o `rclone` e o `rclone.conf` do sistema.

---

## ⚠️ Limites operacionais

- **Teto de upload do Google:** ~750 GiB/dia (não documentado). O backup tem ~197 GiB, cabe; uma repetição no mesmo dia pode bater no teto.
- **Nº de arquivos manda no tempo**, não os GB: ~10 requisições/s na API. 1,1 M arquivos pequenos dominam o relógio.
- **Conta institucional/Workspace:** 5 TiB é cota típica de faculdade. Guardar backup pessoal pode violar a política — se o admin suspender a conta, o backup vai junto.
- **`--dir-cache-time 1000h`** esconde mudanças feitas por *outro* cliente na mesma pasta — mais um motivo para o backup ter destino exclusivo.

---

## 🆘 Resgate de disco com defeito

Quando o disco de origem está morrendo (`input/output error`, link SATA caindo), o backup normal não serve: `--transfers 8` derruba o link. O procedimento que funcionou:

1. Montar **somente leitura** (e com `ntfs3`, que tolera metadados inconsistentes melhor que o `ntfs-3g`):

   ```bash
   sudo mount -t ntfs3 -o ro /dev/sdX2 /mnt/sandisk
   ```

2. Copiar **por prioridade**, com `--transfers 2 --checkers 4 --retries 2 --low-level-retries 5`. O `copy` é incremental: rodar de novo só reenvia o que faltou.
3. Verificar o link: `sudo dmesg -T | grep -E 'hard resetting|detaching'`. Se o disco desanexa, não há software que resolva — é cabo/alimentação/porta.
4. Extrair a lista de falhas para uma segunda passada:

   ```bash
   grep -E 'ERROR.*Failed to (copy|make directory)' ~/backup-resgate.log \
     | sed -E 's/^.*ERROR *: *//; s/: Failed.*//' | sort -u > ~/backup-resgate-falhas.txt
   ```

**Não insista** num disco que reinicia o link a cada poucos segundos: cada reset interrompe a leitura e o ganho é quase zero. Pare, corrija o hardware (cabo SATA, conector de energia, outra porta ou adaptador USB-SATA) e retome — o `copy` continua de onde parou.

---

## 🔧 Diagnóstico rápido



```bash
./scripts/setup-rclone.sh --status
```

Mostra versão, permissões do `rclone.conf`, se o token está válido e o estado dos dois units. É o primeiro comando quando "o Drive parou de funcionar".
