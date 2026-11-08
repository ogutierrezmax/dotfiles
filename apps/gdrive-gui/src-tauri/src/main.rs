// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum TransferState {
    Aguardando,
    Uploading,
    Uploaded,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum FileLocation {
    Nuvem,
    Local,
    Ambos,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DriveItem {
    pub name: String,
    pub rel_path: String,
    pub is_dir: bool,
    pub size: u64,
    pub modified_ts: u64,
    pub modified_str: String,
    pub location: FileLocation,
    pub sync_state: TransferState,
    pub progress_percent: u8,
    pub status_note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadQueueItem {
    pub id: String,
    pub source_path: String,
    pub target_rel_dir: String,
    pub target_name: String,
    pub size: u64,
    pub transferred_bytes: u64,
    pub state: TransferState,
    pub error_message: Option<String>,
    pub created_ts: u64,
    pub updated_ts: u64,
    pub parent_folder: Option<String>,
    pub rel_file_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreviewResult {
    pub name: String,
    pub rel_path: String,
    pub is_dir: bool,
    pub size: u64,
    pub modified_str: String,
    pub mime_guess: String,
    pub is_text: bool,
    pub is_image: bool,
    pub content: String,
    pub truncated: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveTransfer {
    pub name: String,
    pub percentage: u8,
    pub bytes: u64,
    pub size: u64,
    pub speed_avg: f64,
    pub eta: Option<u64>,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DashboardResponse {
    pub mount_active: bool,
    pub backup_active: bool,
    pub backup_timer_active: bool,
    pub vfs_disk_used: u64,
    pub vfs_disk_max: u64,
    pub vfs_queued_count: u64,
    pub vfs_uploading_count: u64,
    pub app_queue: Vec<UploadQueueItem>,
    pub mount_transfers: Vec<ActiveTransfer>,
    pub backup_transfers: Vec<ActiveTransfer>,
    pub last_synced_files: Vec<String>,
}

pub struct AppState {
    pub queue: Arc<Mutex<Vec<UploadQueueItem>>>,
    pub worker_active: Arc<AtomicBool>,
}

fn home_dir() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/home/max"))
}

fn gdrive_root() -> PathBuf {
    home_dir().join("GoogleDrive")
}

pub fn resolve_path(rel_path: &str) -> Result<PathBuf, String> {
    let clean = rel_path.trim_matches('/');
    if clean.contains("..") {
        return Err("Caminho inválido: tentativa de escape de diretório".to_string());
    }
    if clean.is_empty() {
        return Err("Raiz virtual de locais não possui caminho direto em disco".to_string());
    }

    if clean == "GoogleDrive" {
        Ok(gdrive_root())
    } else if let Some(sub) = clean.strip_prefix("GoogleDrive/") {
        Ok(gdrive_root().join(sub))
    } else if clean == "SanDisk-1TB" {
        Ok(PathBuf::from("/mnt/sandisk"))
    } else if let Some(sub) = clean.strip_prefix("SanDisk-1TB/") {
        Ok(PathBuf::from("/mnt/sandisk").join(sub))
    } else {
        Ok(gdrive_root().join(clean))
    }
}

pub fn is_root_dir(rel_path: &str) -> bool {
    let clean = rel_path.trim_matches('/');
    clean.is_empty()
        || clean == "GoogleDrive"
        || clean == "SanDisk-1TB"
}

// Ensure rel_path is strictly within ~/GoogleDrive (backward compat)
pub fn sanitize_rel_path(rel_path: &str) -> Result<PathBuf, String> {
    resolve_path(rel_path)
}

pub fn format_timestamp(ts: u64) -> String {
    if ts == 0 {
        return "-".to_string();
    }
    chrono_light(ts)
}

// Lightweight timestamp formatter without big external timezone crates
fn chrono_light(secs: u64) -> String {
    let days = secs / 86400;
    let time_secs = secs % 86400;
    let hours = time_secs / 3600;
    let mins = (time_secs % 3600) / 60;
    let s = time_secs % 60;
    // Approximated date calculation since 1970
    let mut y = 1970;
    let mut rem_days = days;
    loop {
        let leap = if (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0) { 366 } else { 365 };
        if rem_days < leap {
            break;
        }
        rem_days -= leap;
        y += 1;
    }
    let is_leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    let month_days = [
        31, if is_leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ];
    let mut m = 0;
    for (idx, &md) in month_days.iter().enumerate() {
        if rem_days < md {
            m = idx + 1;
            break;
        }
        rem_days -= md;
    }
    let d = rem_days + 1;
    format!("{:04}-{:02}-{:02} {:02}:{:02}:{:02}", y, m, d, hours, mins, s)
}

fn query_rc(port: u16, command: &str) -> Option<serde_json::Value> {
    let output = Command::new("rclone")
        .args([
            "rc",
            command,
            &format!("--rc-addr=127.0.0.1:{}", port),
            "--rc-no-auth",
        ])
        .output()
        .ok()?;

    if output.status.success() {
        serde_json::from_slice(&output.stdout).ok()
    } else {
        None
    }
}

fn systemd_status(unit: &str) -> bool {
    let output = Command::new("systemctl")
        .args(["--user", "is-active", unit])
        .output();
    match output {
        Ok(out) => {
            let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
            s == "active"
        }
        Err(_) => false,
    }
}

pub fn guess_mime(name: &str) -> (String, bool, bool) {
    let ext = name.split('.').last().unwrap_or("").to_lowercase();
    match ext.as_str() {
        "txt" | "log" | "sh" | "zsh" | "bash" | "conf" | "service" | "timer" | "desktop"
        | "ini" | "env" => ("text/plain".into(), true, false),
        "md" | "markdown" => ("text/markdown".into(), true, false),
        "json" | "jsonc" => ("application/json".into(), true, false),
        "js" | "ts" | "jsx" | "tsx" | "mjs" => ("application/javascript".into(), true, false),
        "rs" => ("text/x-rust".into(), true, false),
        "html" | "htm" => ("text/html".into(), true, false),
        "css" => ("text/css".into(), true, false),
        "yaml" | "yml" => ("text/yaml".into(), true, false),
        "xml" | "svg" => ("image/svg+xml".into(), true, true),
        "png" => ("image/png".into(), false, true),
        "jpg" | "jpeg" => ("image/jpeg".into(), false, true),
        "gif" => ("image/gif".into(), false, true),
        "webp" => ("image/webp".into(), false, true),
        "pdf" => ("application/pdf".into(), false, false),
        "docx" => ("application/vnd.openxmlformats-officedocument.wordprocessingml.document".into(), false, false),
        "xlsx" => ("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".into(), false, false),
        "pptx" => ("application/vnd.openxmlformats-officedocument.presentationml.presentation".into(), false, false),
        "zip" | "tar" | "gz" | "7z" => ("application/zip".into(), false, false),
        _ => ("application/octet-stream".into(), false, false),
    }
}

fn is_in_vfs_cache(rel_path: &str) -> bool {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/max".to_string());
    let cache_base = PathBuf::from(home).join(".cache/rclone/vfs");
    if let Ok(entries) = fs::read_dir(&cache_base) {
        for entry in entries.flatten() {
            let candidate = entry.path().join(rel_path);
            if candidate.exists() {
                return true;
            }
        }
    }
    false
}

// ----------------------------------------------------------------------------
// TAURI COMMANDS
// ----------------------------------------------------------------------------

#[tauri::command]
fn list_directory(rel_path: String, state: State<AppState>) -> Result<Vec<DriveItem>, String> {
    let clean_rel = rel_path.trim_matches('/').to_string();

    if clean_rel.is_empty() {
        let home = home_dir();
        let backup_running = systemd_status("rclone-backup.service");
        let roots_info = [
            (
                "GoogleDrive",
                "GoogleDrive",
                home.join("GoogleDrive"),
                FileLocation::Ambos,
                TransferState::Uploaded,
                100,
                "FUSE Mount do Google Drive (~/GoogleDrive)",
            ),
            (
                "SanDisk-1TB",
                "SanDisk-1TB",
                PathBuf::from("/mnt/sandisk"),
                FileLocation::Ambos,
                if backup_running { TransferState::Uploading } else { TransferState::Uploaded },
                if backup_running { 50 } else { 100 },
                if backup_running { "SSD Externo 1TB (Backup em andamento...)" } else { "SSD Externo 1TB (/mnt/sandisk - Sincronizado)" },
            ),
        ];

        let mut items = Vec::new();
        for (name, rel, path, loc, state, progress, note) in roots_info {
            let meta = fs::metadata(&path).ok();
            let mod_ts = meta
                .as_ref()
                .and_then(|m| m.modified().ok())
                .and_then(|st| st.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_secs())
                .unwrap_or(0);

            items.push(DriveItem {
                name: name.to_string(),
                rel_path: rel.to_string(),
                is_dir: true,
                size: 0,
                modified_ts: mod_ts,
                modified_str: format_timestamp(mod_ts),
                location: loc,
                sync_state: state,
                progress_percent: progress,
                status_note: note.to_string(),
            });
        }
        return Ok(items);
    }

    let dir_path = resolve_path(&rel_path)?;
    if !dir_path.exists() {
        return Err(format!("Diretório não encontrado: {}", dir_path.display()));
    }

    let entries = fs::read_dir(&dir_path)
        .map_err(|e| format!("Erro ao ler diretório {}: {}", dir_path.display(), e))?;

    // Query VFS queue on 5576 to cross-reference items in queue
    let vfs_queue_val = query_rc(5576, "vfs/queue");
    let mut queued_names: Vec<String> = Vec::new();
    let mut uploading_names: Vec<String> = Vec::new();

    if let Some(val) = vfs_queue_val {
        if let Some(arr) = val.get("queue").and_then(|q| q.as_array()) {
            for q_item in arr {
                let name = q_item.get("name").and_then(|n| n.as_str()).unwrap_or("");
                let is_uploading = q_item.get("uploading").and_then(|u| u.as_bool()).unwrap_or(false);
                if !name.is_empty() {
                    let base_name = Path::new(name).file_name().and_then(|f| f.to_str()).unwrap_or(name);
                    if is_uploading {
                        uploading_names.push(base_name.to_string());
                    } else {
                        queued_names.push(base_name.to_string());
                    }
                }
            }
        }
    }

    let mut items = Vec::new();

    for entry_res in entries {
        let entry = match entry_res {
            Ok(e) => e,
            Err(_) => continue,
        };
        let file_name = entry.file_name().to_string_lossy().to_string();
        // Skip hidden or system-internal metadata
        if file_name.starts_with(".fuse_hidden") {
            continue;
        }

        let meta = entry.metadata().ok();
        let is_dir = meta.as_ref().map(|m| m.is_dir()).unwrap_or(false);
        let size = if is_dir { 0 } else { meta.as_ref().map(|m| m.len()).unwrap_or(0) };

        let mod_ts = meta
            .as_ref()
            .and_then(|m| m.modified().ok())
            .and_then(|st| st.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);

        let item_rel = format!("{}/{}", clean_rel, file_name);

        let mut sync_state = TransferState::Uploaded;
        let mut progress = 100;
        let mut note = "Sincronizado".to_string();
        let location = if is_dir {
            if clean_rel.starts_with("GoogleDrive") || clean_rel.starts_with("SanDisk-1TB") {
                FileLocation::Ambos
            } else {
                FileLocation::Local
            }
        } else if uploading_names.iter().any(|n| n == &file_name) {
            sync_state = TransferState::Uploading;
            progress = 50;
            note = "Enviando para nuvem...".to_string();
            FileLocation::Local
        } else if queued_names.iter().any(|n| n == &file_name) {
            sync_state = TransferState::Aguardando;
            progress = 0;
            note = "Na fila de envio VFS".to_string();
            FileLocation::Local
        } else if clean_rel.starts_with("GoogleDrive") {
            let sub = item_rel.strip_prefix("GoogleDrive/").unwrap_or(&file_name);
            if is_in_vfs_cache(sub) {
                FileLocation::Ambos
            } else {
                FileLocation::Nuvem
            }
        } else if clean_rel.starts_with("SanDisk-1TB") {
            FileLocation::Ambos
        } else {
            FileLocation::Local
        };

        items.push(DriveItem {
            name: file_name,
            rel_path: item_rel,
            is_dir,
            size,
            modified_ts: mod_ts,
            modified_str: format_timestamp(mod_ts),
            location,
            sync_state,
            progress_percent: progress,
            status_note: note,
        });
    }

    // Merge items from app upload queue
    {
        let q = state.queue.lock().unwrap();
        for it in q.iter() {
            let target_dir_clean = it.target_rel_dir.trim_matches('/');
            if target_dir_clean == clean_rel {
                if let Some(existing) = items.iter_mut().find(|i| i.name == it.target_name) {
                    if it.state == TransferState::Uploaded {
                        existing.location = FileLocation::Ambos;
                        existing.sync_state = TransferState::Uploaded;
                        existing.progress_percent = 100;
                    } else {
                        existing.location = FileLocation::Local;
                        existing.sync_state = it.state.clone();
                        existing.progress_percent = if it.size > 0 {
                            ((it.transferred_bytes * 100) / it.size).min(99) as u8
                        } else {
                            50
                        };
                    }
                } else if it.state != TransferState::Uploaded {
                    let pct = if it.size > 0 {
                        ((it.transferred_bytes * 100) / it.size).min(99) as u8
                    } else {
                        0
                    };
                    items.push(DriveItem {
                        name: it.target_name.clone(),
                        rel_path: format!("{}/{}", clean_rel, it.target_name),
                        is_dir: false,
                        size: it.size,
                        modified_ts: it.created_ts,
                        modified_str: format_timestamp(it.created_ts),
                        location: FileLocation::Local,
                        sync_state: it.state.clone(),
                        progress_percent: pct,
                        status_note: "Na fila de upload local".to_string(),
                    });
                }
            }
        }
    }

    // Sort: directories first, then alphabetical by name
    items.sort_by(|a, b| match (a.is_dir, b.is_dir) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
    });

    Ok(items)
}

#[tauri::command]
fn preview_file(rel_path: String) -> Result<PreviewResult, String> {
    let clean = rel_path.trim_matches('/');
    if clean.is_empty() {
        return Ok(PreviewResult {
            name: "Início (Locais & Drives)".to_string(),
            rel_path: String::new(),
            is_dir: true,
            size: 0,
            modified_str: "-".to_string(),
            mime_guess: "inode/directory".to_string(),
            is_text: false,
            is_image: false,
            content: "Visão raiz agregada de unidades locais e montagem em nuvem.".to_string(),
            truncated: false,
        });
    }

    let path = resolve_path(&rel_path)?;
    if !path.exists() {
        return Err("Arquivo não encontrado".to_string());
    }

    let meta = fs::metadata(&path).map_err(|e| e.to_string())?;
    let is_dir = meta.is_dir();
    let size = if is_dir { 0 } else { meta.len() };
    let mod_ts = meta
        .modified()
        .ok()
        .and_then(|st| st.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let name = path
        .file_name()
        .map(|f| f.to_string_lossy().to_string())
        .unwrap_or_else(|| rel_path.clone());

    let (mime, is_text, is_image) = guess_mime(&name);
    let mut content = String::new();
    let mut truncated = false;

    if is_dir {
        content = format!("Diretório: {}", path.display());
    } else if is_text {
        // Read text up to 256KB
        const MAX_BYTES: u64 = 256 * 1024;
        let read_len = std::cmp::min(size, MAX_BYTES) as usize;
        let mut buf = vec![0u8; read_len];
        use std::io::Read;
        if let Ok(mut f) = fs::File::open(&path) {
            let _ = f.read_exact(&mut buf);
            content = String::from_utf8_lossy(&buf).to_string();
            if size > MAX_BYTES {
                truncated = true;
            }
        }
    } else if is_image {
        // Base64 encode for small/medium images (up to 4MB)
        if size <= 4 * 1024 * 1024 {
            if let Ok(bytes) = fs::read(&path) {
                use base64_light::encode_b64;
                content = format!("data:{};base64,{}", mime, encode_b64(&bytes));
            }
        } else {
            content = "Imagem muito grande para preview integrado".to_string();
        }
    }

    Ok(PreviewResult {
        name,
        rel_path,
        is_dir,
        size,
        modified_str: format_timestamp(mod_ts),
        mime_guess: mime,
        is_text,
        is_image,
        content,
        truncated,
    })
}

mod base64_light {
    pub fn encode_b64(input: &[u8]) -> String {
        const CHARS: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let mut result = String::with_capacity((input.len() + 2) / 3 * 4);
        for chunk in input.chunks(3) {
            let b0 = chunk[0];
            let b1 = if chunk.len() > 1 { chunk[1] } else { 0 };
            let b2 = if chunk.len() > 2 { chunk[2] } else { 0 };

            let c0 = b0 >> 2;
            let c1 = ((b0 & 3) << 4) | (b1 >> 4);
            let c2 = ((b1 & 15) << 2) | (b2 >> 6);
            let c3 = b2 & 63;

            result.push(CHARS[c0 as usize] as char);
            result.push(CHARS[c1 as usize] as char);
            if chunk.len() > 1 {
                result.push(CHARS[c2 as usize] as char);
            } else {
                result.push('=');
            }
            if chunk.len() > 2 {
                result.push(CHARS[c3 as usize] as char);
            } else {
                result.push('=');
            }
        }
        result
    }
}

#[tauri::command]
fn create_folder(rel_path: String, folder_name: String) -> Result<(), String> {
    let clean_name = folder_name.trim();
    if clean_name.is_empty() || clean_name.contains('/') || clean_name.contains("..") {
        return Err("Nome de pasta inválido".to_string());
    }
    let clean_rel = rel_path.trim_matches('/');
    if clean_rel.is_empty() {
        return Err("Não é permitido criar pastas na raiz de Locais. Entre em uma pasta primeiro (ex: GoogleDrive).".to_string());
    }
    let parent = resolve_path(&rel_path)?;
    let target = parent.join(clean_name);
    fs::create_dir_all(&target).map_err(|e| format!("Erro ao criar pasta: {}", e))?;
    Ok(())
}

#[tauri::command]
fn rename_entry(rel_path: String, new_name: String) -> Result<(), String> {
    let clean_new = new_name.trim();
    if clean_new.is_empty() || clean_new.contains('/') || clean_new.contains("..") {
        return Err("Novo nome inválido".to_string());
    }
    if is_root_dir(&rel_path) {
        return Err("Não é permitido renomear pastas raiz do sistema".to_string());
    }
    let source = resolve_path(&rel_path)?;
    let parent = source.parent().ok_or("Diretório pai inválido")?;
    let target = parent.join(clean_new);
    fs::rename(&source, &target).map_err(|e| format!("Erro ao renomear: {}", e))?;
    Ok(())
}

#[tauri::command]
fn delete_entry(rel_path: String) -> Result<(), String> {
    if is_root_dir(&rel_path) {
        return Err("Não é permitido excluir pastas raiz do sistema".to_string());
    }
    let target = resolve_path(&rel_path)?;
    if !target.exists() {
        return Err("Item não encontrado".to_string());
    }
    if target.is_dir() {
        fs::remove_dir_all(&target).map_err(|e| format!("Erro ao excluir pasta: {}", e))?;
    } else {
        fs::remove_file(&target).map_err(|e| format!("Erro ao excluir arquivo: {}", e))?;
    }
    Ok(())
}

#[tauri::command]
fn open_in_system(rel_path: String, reveal: bool) -> Result<(), String> {
    let clean = rel_path.trim_matches('/');
    let target = if clean.is_empty() {
        home_dir()
    } else {
        resolve_path(&rel_path)?
    };

    if !target.exists() {
        return Err("Caminho não encontrado".to_string());
    }

    if reveal {
        // Reveal with Dolphin or xdg-open parent
        let _ = Command::new("dolphin")
            .args(["--select", &target.to_string_lossy()])
            .spawn()
            .or_else(|_| {
                let parent = target.parent().unwrap_or(&target);
                Command::new("xdg-open").arg(parent).spawn()
            });
    } else {
        let _ = Command::new("xdg-open").arg(&target).spawn();
    }
    Ok(())
}

fn collect_folder_files(
    root: &Path,
    current: &Path,
    results: &mut Vec<(PathBuf, String, u64)>,
) {
    if let Ok(entries) = fs::read_dir(current) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.is_dir() {
                collect_folder_files(root, &p, results);
            } else if p.is_file() {
                let rel = p.strip_prefix(root).unwrap_or(&p).to_string_lossy().to_string();
                let sz = fs::metadata(&p).map(|m| m.len()).unwrap_or(0);
                results.push((p, rel, sz));
            }
        }
    }
}

#[tauri::command]
fn enqueue_uploads(
    source_paths: Vec<String>,
    target_rel_dir: String,
    state: State<AppState>,
) -> Result<Vec<UploadQueueItem>, String> {
    let effective_target = if target_rel_dir.trim_matches('/').is_empty() {
        "GoogleDrive".to_string()
    } else {
        target_rel_dir.clone()
    };
    let target_dir = resolve_path(&effective_target)?;
    if !target_dir.exists() {
        fs::create_dir_all(&target_dir).map_err(|e| e.to_string())?;
    }

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    let mut new_items = Vec::new();
    let mut queue_guard = state.queue.lock().unwrap();

    for src_str in source_paths {
        let src_path = PathBuf::from(&src_str);
        if !src_path.exists() {
            continue;
        }

        if src_path.is_dir() {
            let folder_name = src_path
                .file_name()
                .map(|f| f.to_string_lossy().to_string())
                .unwrap_or_else(|| "pasta".to_string());

            let mut files = Vec::new();
            collect_folder_files(&src_path, &src_path, &mut files);

            if files.is_empty() {
                let empty_target = format!("{}/{}", effective_target.trim_matches('/'), folder_name);
                if let Ok(d) = resolve_path(&empty_target) {
                    let _ = fs::create_dir_all(&d);
                }
            } else {
                for (file_path, rel_sub, f_size) in files {
                    let file_name = file_path
                        .file_name()
                        .map(|f| f.to_string_lossy().to_string())
                        .unwrap_or_else(|| "arquivo".to_string());

                    let rel_parent = Path::new(&rel_sub)
                        .parent()
                        .map(|p| p.to_string_lossy().to_string())
                        .unwrap_or_default();

                    let item_target_rel = if rel_parent.is_empty() {
                        format!("{}/{}", effective_target.trim_matches('/'), folder_name)
                    } else {
                        format!("{}/{}/{}", effective_target.trim_matches('/'), folder_name, rel_parent)
                    };

                    let id = format!("{}_{}_{}", now, file_name, queue_guard.len());
                    let item = UploadQueueItem {
                        id,
                        source_path: file_path.to_string_lossy().to_string(),
                        target_rel_dir: item_target_rel,
                        target_name: file_name,
                        size: f_size,
                        transferred_bytes: 0,
                        state: TransferState::Aguardando,
                        error_message: None,
                        created_ts: now,
                        updated_ts: now,
                        parent_folder: Some(folder_name.clone()),
                        rel_file_path: Some(rel_sub),
                    };

                    queue_guard.push(item.clone());
                    new_items.push(item);
                }
            }
        } else {
            let name = src_path
                .file_name()
                .map(|f| f.to_string_lossy().to_string())
                .unwrap_or_else(|| "arquivo".to_string());

            let size = fs::metadata(&src_path).map(|m| m.len()).unwrap_or(0);
            let id = format!("{}_{}_{}", now, name, queue_guard.len());
            let item = UploadQueueItem {
                id,
                source_path: src_str,
                target_rel_dir: effective_target.clone(),
                target_name: name,
                size,
                transferred_bytes: 0,
                state: TransferState::Aguardando,
                error_message: None,
                created_ts: now,
                updated_ts: now,
                parent_folder: None,
                rel_file_path: None,
            };

            queue_guard.push(item.clone());
            new_items.push(item);
        }
    }

    start_upload_worker(&state);

    Ok(new_items)
}

fn start_upload_worker(state: &AppState) {
    if state.worker_active.swap(true, Ordering::SeqCst) {
        return; // Already active
    }

    let queue_arc = Arc::clone(&state.queue);
    let flag_arc = Arc::clone(&state.worker_active);

    std::thread::spawn(move || {
        loop {
            let next_item = {
                let mut q = queue_arc.lock().unwrap();
                let mut found_idx = None;
                for (idx, item) in q.iter_mut().enumerate() {
                    if item.state == TransferState::Aguardando {
                        item.state = TransferState::Uploading;
                        item.updated_ts = SystemTime::now()
                            .duration_since(UNIX_EPOCH)
                            .unwrap_or_default()
                            .as_secs();
                        found_idx = Some(idx);
                        break;
                    }
                }
                found_idx.map(|idx| q[idx].clone())
            };

            let item = match next_item {
                Some(it) => it,
                None => {
                    flag_arc.store(false, Ordering::SeqCst);
                    break;
                }
            };

            let src = PathBuf::from(&item.source_path);
            let dest_dir = match sanitize_rel_path(&item.target_rel_dir) {
                Ok(d) => d,
                Err(err) => {
                    mark_item_result(&queue_arc, &item.id, TransferState::Error, Some(err));
                    continue;
                }
            };
            if !dest_dir.exists() {
                if let Err(e) = fs::create_dir_all(&dest_dir) {
                    mark_item_result(&queue_arc, &item.id, TransferState::Error, Some(e.to_string()));
                    continue;
                }
            }
            let dest_file = dest_dir.join(&item.target_name);

            // Copy file with byte progress
            let copy_res = if src.is_dir() {
                copy_recursive(&src, &dest_file)
            } else {
                copy_file_with_progress(&src, &dest_file, &queue_arc, &item.id, item.size)
            };

            match copy_res {
                Ok(_) => {
                    mark_item_result(&queue_arc, &item.id, TransferState::Uploaded, None);
                }
                Err(e) => {
                    mark_item_result(&queue_arc, &item.id, TransferState::Error, Some(e));
                }
            }
        }
    });
}

fn copy_file_with_progress(
    src: &Path,
    dst: &Path,
    queue: &Arc<Mutex<Vec<UploadQueueItem>>>,
    id: &str,
    total_size: u64,
) -> Result<(), String> {
    use std::io::{Read, Write};
    let mut reader = fs::File::open(src).map_err(|e| e.to_string())?;
    let mut writer = fs::File::create(dst).map_err(|e| e.to_string())?;

    let mut buffer = [0u8; 64 * 1024]; // 64KB buffer
    let mut copied: u64 = 0;
    let mut last_update = SystemTime::now();

    loop {
        let bytes_read = reader.read(&mut buffer).map_err(|e| e.to_string())?;
        if bytes_read == 0 {
            break;
        }
        writer.write_all(&buffer[..bytes_read]).map_err(|e| e.to_string())?;
        copied += bytes_read as u64;

        if last_update.elapsed().map(|d| d.as_millis()).unwrap_or(0) > 100 {
            last_update = SystemTime::now();
            let mut q = queue.lock().unwrap();
            if let Some(it) = q.iter_mut().find(|it| it.id == id) {
                it.transferred_bytes = copied;
                it.updated_ts = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
            }
        }
    }

    writer.flush().map_err(|e| e.to_string())?;
    let mut q = queue.lock().unwrap();
    if let Some(it) = q.iter_mut().find(|it| it.id == id) {
        it.transferred_bytes = total_size;
    }
    Ok(())
}

fn copy_recursive(src: &Path, dst: &Path) -> Result<(), String> {
    if !dst.exists() {
        fs::create_dir_all(dst).map_err(|e| e.to_string())?;
    }
    for entry in fs::read_dir(src).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let entry_path = entry.path();
        let target_path = dst.join(entry.file_name());
        if entry_path.is_dir() {
            copy_recursive(&entry_path, &target_path)?;
        } else {
            fs::copy(&entry_path, &target_path).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

fn mark_item_result(
    queue: &Arc<Mutex<Vec<UploadQueueItem>>>,
    id: &str,
    state: TransferState,
    error: Option<String>,
) {
    let mut q = queue.lock().unwrap();
    if let Some(it) = q.iter_mut().find(|it| it.id == id) {
        it.state = state;
        it.error_message = error;
        it.updated_ts = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
    }
}

#[tauri::command]
fn clear_completed_uploads(state: State<AppState>) -> Result<(), String> {
    let mut q = state.queue.lock().unwrap();
    q.retain(|it| it.state != TransferState::Uploaded);
    Ok(())
}

#[tauri::command]
fn remove_queue_item(id: String, state: State<AppState>) -> Result<(), String> {
    let mut q = state.queue.lock().unwrap();
    q.retain(|it| it.id != id);
    Ok(())
}

#[tauri::command]
fn retry_upload(id: String, state: State<AppState>) -> Result<(), String> {
    {
        let mut q = state.queue.lock().unwrap();
        if let Some(it) = q.iter_mut().find(|it| it.id == id) {
            it.state = TransferState::Aguardando;
            it.error_message = None;
            it.transferred_bytes = 0;
            it.updated_ts = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
        }
    }
    start_upload_worker(&state);
    Ok(())
}

#[tauri::command]
fn get_transfer_dashboard(state: State<AppState>) -> Result<DashboardResponse, String> {
    let mount_active = systemd_status("rclone-gdrive.service");
    let backup_active = systemd_status("rclone-backup.service");
    let backup_timer_active = systemd_status("rclone-backup.timer");

    // Query 5576 VFS Stats
    let mut vfs_disk_used = 0;
    let mut vfs_disk_max = 8 * 1024 * 1024 * 1024; // 8 GiB default from service
    let mut vfs_queued_count = 0;
    let mut vfs_uploading_count = 0;
    let mut mount_transfers = Vec::new();

    if let Some(vfs) = query_rc(5576, "vfs/stats") {
        if let Some(dc) = vfs.get("diskCache") {
            vfs_disk_used = dc.get("bytesUsed").and_then(|b| b.as_u64()).unwrap_or(0);
            vfs_queued_count = dc.get("uploadsQueued").and_then(|u| u.as_u64()).unwrap_or(0);
            vfs_uploading_count = dc.get("uploadsInProgress").and_then(|u| u.as_u64()).unwrap_or(0);
        }
        if let Some(opt) = vfs.get("opt") {
            vfs_disk_max = opt.get("CacheMaxSize").and_then(|m| m.as_u64()).unwrap_or(vfs_disk_max);
        }
    }

    if let Some(stats) = query_rc(5576, "core/stats") {
        if let Some(arr) = stats.get("transferring").and_then(|t| t.as_array()) {
            for t in arr {
                mount_transfers.push(ActiveTransfer {
                    name: t.get("name").and_then(|n| n.as_str()).unwrap_or("").to_string(),
                    percentage: t.get("percentage").and_then(|p| p.as_u64()).unwrap_or(0) as u8,
                    bytes: t.get("bytes").and_then(|b| b.as_u64()).unwrap_or(0),
                    size: t.get("size").and_then(|s| s.as_u64()).unwrap_or(0),
                    speed_avg: t.get("speedAvg").and_then(|s| s.as_f64()).unwrap_or(0.0),
                    eta: t.get("eta").and_then(|e| e.as_u64()),
                    source: "Mount VFS".to_string(),
                });
            }
        }
    }

    // Query 5577 Backup Stats
    let mut backup_transfers = Vec::new();
    let mut last_synced_files = Vec::new();

    if let Some(stats) = query_rc(5577, "core/stats") {
        if let Some(arr) = stats.get("transferring").and_then(|t| t.as_array()) {
            for t in arr {
                backup_transfers.push(ActiveTransfer {
                    name: t.get("name").and_then(|n| n.as_str()).unwrap_or("").to_string(),
                    percentage: t.get("percentage").and_then(|p| p.as_u64()).unwrap_or(0) as u8,
                    bytes: t.get("bytes").and_then(|b| b.as_u64()).unwrap_or(0),
                    size: t.get("size").and_then(|s| s.as_u64()).unwrap_or(0),
                    speed_avg: t.get("speedAvg").and_then(|s| s.as_f64()).unwrap_or(0.0),
                    eta: t.get("eta").and_then(|e| e.as_u64()),
                    source: "Backup SanDisk".to_string(),
                });
            }
        }
    }

    if let Some(trans) = query_rc(5577, "core/transferred") {
        if let Some(arr) = trans.get("transferred").and_then(|t| t.as_array()) {
            for t in arr.iter().take(10) {
                if let Some(name) = t.get("name").and_then(|n| n.as_str()) {
                    last_synced_files.push(name.to_string());
                }
            }
        }
    }

    let app_queue = {
        let q = state.queue.lock().unwrap();
        q.clone()
    };

    Ok(DashboardResponse {
        mount_active,
        backup_active,
        backup_timer_active,
        vfs_disk_used,
        vfs_disk_max,
        vfs_queued_count,
        vfs_uploading_count,
        app_queue,
        mount_transfers,
        backup_transfers,
        last_synced_files,
    })
}

#[tauri::command]
fn control_service(unit: String, action: String) -> Result<String, String> {
    if !["restart", "start", "stop"].contains(&action.as_str()) {
        return Err("Ação não permitida".to_string());
    }
    if !["rclone-gdrive.service", "rclone-backup.service"].contains(&unit.as_str()) {
        return Err("Unidade não permitida".to_string());
    }

    let output = Command::new("systemctl")
        .args(["--user", &action, &unit])
        .output()
        .map_err(|e| e.to_string())?;

    if output.status.success() {
        Ok(format!("Serviço {} executou {}", unit, action))
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

// ----------------------------------------------------------------------------
// MAIN & TESTS
// ----------------------------------------------------------------------------

fn main() {
    let state = AppState {
        queue: Arc::new(Mutex::new(Vec::new())),
        worker_active: Arc::new(AtomicBool::new(false)),
    };

    tauri::Builder::default()
        .manage(state)
        .invoke_handler(tauri::generate_handler![
            list_directory,
            preview_file,
            create_folder,
            rename_entry,
            delete_entry,
            open_in_system,
            enqueue_uploads,
            clear_completed_uploads,
            remove_queue_item,
            retry_upload,
            get_transfer_dashboard,
            control_service,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::{base64_light, chrono_light, guess_mime, home_dir, resolve_path, PathBuf};

    #[test]
    fn test_resolve_path() {
        let home = home_dir();
        assert_eq!(resolve_path("GoogleDrive").unwrap(), home.join("GoogleDrive"));
        assert_eq!(resolve_path("GoogleDrive/Docs").unwrap(), home.join("GoogleDrive/Docs"));
        assert_eq!(resolve_path("SanDisk-1TB").unwrap(), PathBuf::from("/mnt/sandisk"));
        assert_eq!(resolve_path("SanDisk-1TB/Backup").unwrap(), PathBuf::from("/mnt/sandisk/Backup"));
        assert!(resolve_path("../etc/passwd").is_err());
        assert!(resolve_path("GoogleDrive/../../root").is_err());
        assert!(resolve_path("").is_err());
    }

    #[test]
    fn test_guess_mime() {
        let (m1, is_t1, is_i1) = guess_mime("plan.md");
        assert_eq!(m1, "text/markdown");
        assert!(is_t1);
        assert!(!is_i1);

        let (m2, is_t2, is_i2) = guess_mime("photo.png");
        assert_eq!(m2, "image/png");
        assert!(!is_t2);
        assert!(is_i2);

        let (m3, is_t3, is_i3) = guess_mime("archive.zip");
        assert_eq!(m3, "application/zip");
        assert!(!is_t3);
        assert!(!is_i3);
    }

    #[test]
    fn test_base64_encode() {
        assert_eq!(base64_light::encode_b64(b"hello"), "aGVsbG8=");
        assert_eq!(base64_light::encode_b64(b"Rust Tauri 2"), "UnVzdCBUYXVyaSAy");
    }

    #[test]
    fn test_chrono_light() {
        let formatted = chrono_light(1700000000);
        assert!(formatted.starts_with("2023-11-14"));
    }
}
