# ☁️ Google Drive Manager (`gdrive-gui`)

> Interface gráfica Desktop em Tauri 2 para visualização, navegação, gerenciamento de arquivos e monitoramento de transferências do Google Drive com rastreamento de estados em tempo real.

---

## 🛠 Tech Stack

| Camada | Tecnologia | Função |
| :--- | :--- | :--- |
| **Frontend** | TypeScript + HTML5 / CSS3 (Dark Theme) | Interface reativa, drag & drop nativo, KPIs e abas |
| **Backend** | Rust (Tauri 2) | IPC seguro, comandos de filesystem, worker assíncrono de upload |
| **Motor Drive** | `rclone` (VFS mount em `~/GoogleDrive`) | Sincronização em nuvem, leitura via Remote Control (:5576) |
| **Telemetria** | rclone RC (`:5576` Mount, `:5577` Backup) | Fila VFS write-back e progresso ao vivo |
| **Orquestração** | `systemd --user` | `rclone-gdrive.service` e `rclone-backup.service` |

---

## 🧭 Rastreamento de Estados

A aplicação monitora e unifica três estados principais:

1. **⏳ Aguardando (`aguardando`)**:
   - Arquivo inserido na fila local do app aguardando início da cópia para o mount.
   - Arquivo presente na fila de write-back do VFS (`vfs/queue` com `uploading == false`).
2. **⬆️ Uploading (`uploading`)**:
   - Transferência ativa no worker local ou no buffer do rclone.
   - Acompanhamento com barra de progresso, bytes transmitidos, velocidade média e ETA via `core/stats` e `vfs/queue`.
3. **✅ Uploaded (`uploaded`)**:
   - Arquivo sincronizado no diretório remoto do Google Drive.
   - Confirmado via `core/transferred` ou presença persistida no mount.

### Unificação da Raiz (`~/GoogleDrive`) e Síntese de Pastas
- **Raiz Unificada (`~/GoogleDrive`)**: A raiz do explorador (`rel_path == ""` ou `"GoogleDrive"`) lista diretamente o conteúdo de `~/GoogleDrive`, refletindo a mesma hierarquia da nuvem (`gdrive:`).
- **Projeção de `Backup-SanDisk-1TB`**: Como o `rclone-gdrive.service` exclui `--exclude="/Backup-SanDisk-1TB/**"` do FUSE mount para não duplicar o VFS cache, o `gdrive-gui` projeta a pasta `Backup-SanDisk-1TB` diretamente na raiz de `~/GoogleDrive` (mapeando `/mnt/sandisk` como somente-leitura e agregando a telemetria ao vivo do `rclone-backup.service` na porta `:5577`).
- **Síntese e Propagação de Pastas em Tempo Real**: Quando pastas ou subpastas são adicionadas à fila de upload (`state.queue`) ou estão em write-back no VFS (`:5576`), `list_directory` sintetiza os diretórios intermediários ainda não materializados no mount e propaga o estado agregado (`Uploading` > `Aguardando` > `Uploaded`) dos arquivos internos para as pastas pai, atualizando a tabela principal silenciosamente a cada ciclo de polling.

---

## 🚀 Como Executar

```bash
# Executar a aplicação (compila automaticamente se houver mudanças)
gdrive-gui

# Recompilar explicitamente em modo release
gdrive-gui --build

# Executar em modo desenvolvimento
gdrive-gui --dev
```

A aplicação também está disponível no menu de aplicativos do sistema como **Google Drive Manager**.
