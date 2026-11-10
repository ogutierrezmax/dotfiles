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
pub struct BackupStats {
    pub is_active: bool,
    pub bytes: u64,
    pub total_bytes: u64,
    pub transfers_done: u64,
    pub total_transfers: u64,
    pub pending_transfers: u64,
    pub pending_bytes: u64,
    pub active_count: usize,
    pub speed: f64,
    pub eta: Option<u64>,
    pub errors: u64,
    pub percentage: u8,
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
    pub backup_stats: Option<BackupStats>,
    pub last_synced_files: Vec<String>,
}

pub struct AppState {
    pub queue: Arc<Mutex<Vec<UploadQueueItem>>>,
    pub worker_active: Arc<AtomicBool>,
    pub backup_remote_cache: Arc<Mutex<std::collections::HashMap<String, (u64, Vec<String>)>>>,
    pub folder_progress_cache: Arc<Mutex<std::collections::HashMap<String, u8>>>,
}

fn gdrive_root() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/home/max"))
        .join("GoogleDrive")
}

pub fn normalize_rel_path(rel_path: &str) -> String {
    let clean = rel_path.trim_matches('/');
    if clean == "GoogleDrive" {
        String::new()
    } else if let Some(sub) = clean.strip_prefix("GoogleDrive/") {
        sub.trim_matches('/').to_string()
    } else {
        clean.to_string()
    }
}

pub fn is_protected_backup_path(rel_path: &str) -> bool {
    let clean = normalize_rel_path(rel_path);
    clean == "Backup-SanDisk-1TB" || clean.starts_with("Backup-SanDisk-1TB/")
}

// Resolve paths inside ~/GoogleDrive, mapping Backup-SanDisk-1TB to /mnt/sandisk
pub fn sanitize_rel_path(rel_path: &str) -> Result<PathBuf, String> {
    let raw = rel_path.trim_matches('/');
    if raw.contains("..") {
        return Err("Caminho inválido: tentativa de escape de diretório".to_string());
    }
    let clean = normalize_rel_path(raw);
    let target = if clean.is_empty() {
        gdrive_root()
    } else if clean == "Backup-SanDisk-1TB" {
        PathBuf::from("/mnt/sandisk")
    } else if let Some(sub) = clean.strip_prefix("Backup-SanDisk-1TB/") {
        PathBuf::from("/mnt/sandisk").join(sub)
    } else {
        gdrive_root().join(clean)
    };
    Ok(target)
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

fn query_rc_with_args(port: u16, command: &str, extra_args: &[&str]) -> Option<serde_json::Value> {
    let addr = format!("--rc-addr=127.0.0.1:{}", port);
    let mut args = vec!["rc", command, &addr, "--rc-no-auth"];
    args.extend_from_slice(extra_args);
    let output = Command::new("rclone").args(args).output().ok()?;
    if output.status.success() {
        serde_json::from_slice(&output.stdout).ok()
    } else {
        None
    }
}

fn fetch_backup_remote_names(
    sub_dir: &str,
    cache: &Arc<Mutex<std::collections::HashMap<String, (u64, Vec<String>)>>>,
) -> Option<Vec<String>> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    if let Ok(guard) = cache.lock() {
        if let Some((ts, cached)) = guard.get(sub_dir) {
            if now.saturating_sub(*ts) < 6 {
                return Some(cached.clone());
            }
        }
    }

    let remote_arg = format!("remote={}", sub_dir.trim_matches('/'));
    let val = query_rc_with_args(
        5577,
        "operations/list",
        &["fs=gdrive:Backup-SanDisk-1TB", &remote_arg],
    )
    .or_else(|| {
        query_rc_with_args(
            5576,
            "operations/list",
            &["fs=gdrive:Backup-SanDisk-1TB", &remote_arg],
        )
    })?;

    let arr = val.get("list")?.as_array()?;
    let mut names: Vec<String> = arr
        .iter()
        .filter_map(|item| item.get("Name").and_then(|n| n.as_str()).map(String::from))
        .collect();

    if let Some(trans) = query_rc(5577, "core/transferred") {
        if let Some(t_arr) = trans.get("transferred").and_then(|t| t.as_array()) {
            let clean_sub = sub_dir.trim_matches('/');
            for t in t_arr {
                if let Some(t_name) = t.get("name").and_then(|n| n.as_str()) {
                    let clean_t = t_name.trim_matches('/');
                    let (p_dir, f_name) = match clean_t.rfind('/') {
                        Some(idx) => (&clean_t[..idx], &clean_t[idx + 1..]),
                        None => ("", clean_t),
                    };
                    if p_dir == clean_sub && !names.iter().any(|n| n == f_name) {
                        names.push(f_name.to_string());
                    }
                }
            }
        }
    }

    if let Ok(mut guard) = cache.lock() {
        guard.insert(sub_dir.to_string(), (now, names.clone()));
    }

    Some(names)
}

pub fn format_bytes_u64(bytes: u64) -> String {
    if bytes == 0 {
        return "0 B".to_string();
    }
    let units = ["B", "KB", "MB", "GB", "TB"];
    let mut b = bytes as f64;
    let mut i = 0;
    while b >= 1024.0 && i < units.len() - 1 {
        b /= 1024.0;
        i += 1;
    }
    format!("{:.1} {}", b, units[i])
}

pub fn calculate_backup_root_progress(
    bytes: u64,
    total_bytes: u64,
    transfers: u64,
    total_transfers: u64,
    active_count: usize,
    last_progress: u8,
    is_running: bool,
) -> (TransferState, u8, String) {
    if !is_running && active_count == 0 {
        return (
            TransferState::Uploaded,
            100,
            "Backup do SSD SanDisk 1TB no Google Drive".to_string(),
        );
    }

    let calculated_pct = if total_bytes > 0 {
        ((bytes * 100) / total_bytes).min(99) as u8
    } else if total_transfers > 0 {
        ((transfers * 100) / total_transfers).min(99) as u8
    } else if active_count > 0 {
        1
    } else {
        0
    };

    let pct = std::cmp::max(last_progress, calculated_pct);

    let note = if total_bytes > 0 && total_transfers > 0 {
        format!(
            "Enviando backup: {}% ({} de {}, {}/{} arquivos)",
            pct,
            format_bytes_u64(bytes),
            format_bytes_u64(total_bytes),
            transfers,
            total_transfers
        )
    } else if active_count > 0 {
        format!("Enviando backup ({} transferências ativas)...", active_count)
    } else {
        "Sincronizando SSD SanDisk 1TB (:5577)...".to_string()
    };

    (TransferState::Uploading, pct.max(1), note)
}

pub fn retain_incomplete_queue(queue: &mut Vec<UploadQueueItem>) {
    let incomplete_folders: std::collections::HashSet<String> = queue
        .iter()
        .filter(|it| it.state != TransferState::Uploaded)
        .filter_map(|it| it.parent_folder.clone())
        .collect();

    let incomplete_targets: std::collections::HashSet<String> = queue
        .iter()
        .filter(|it| it.state != TransferState::Uploaded)
        .map(|it| normalize_rel_path(&it.target_rel_dir))
        .collect();

    queue.retain(|it| {
        if it.state != TransferState::Uploaded {
            return true;
        }
        if let Some(ref pf) = it.parent_folder {
            if incomplete_folders.contains(pf) {
                return true;
            }
        }
        let clean_target = normalize_rel_path(&it.target_rel_dir);
        !clean_target.is_empty() && incomplete_targets.contains(&clean_target)
    });
}

pub fn resolve_backup_item_state(
    sub_rel: &str,
    file_name: &str,
    is_dir: bool,
    backup_transfers_rel: &[(String, u8)],
    remote_names: Option<&[String]>,
    is_backup_running: bool,
    last_folder_pct: u8,
) -> (TransferState, FileLocation, u8, String) {
    let exists_on_remote = remote_names
        .map(|names| names.iter().any(|n| n == file_name))
        .unwrap_or(true);

    if !is_dir {
        if let Some((_, pct)) = backup_transfers_rel.iter().find(|(n, _)| n == sub_rel) {
            (
                TransferState::Uploading,
                FileLocation::Local,
                *pct,
                "Enviando para nuvem (:5577)...".to_string(),
            )
        } else if !exists_on_remote {
            (
                TransferState::Aguardando,
                FileLocation::Local,
                0,
                "Aguardando início do upload (:5577)".to_string(),
            )
        } else {
            (
                TransferState::Uploaded,
                FileLocation::Ambos,
                100,
                "Sincronizado".to_string(),
            )
        }
    } else {
        let prefix = format!("{}/", sub_rel);
        let matching: Vec<u8> = backup_transfers_rel
            .iter()
            .filter(|(n, _)| n == sub_rel || n.starts_with(&prefix))
            .map(|(_, p)| *p)
            .collect();
        if !matching.is_empty() {
            let avg =
                (matching.iter().map(|&p| p as u64).sum::<u64>() / matching.len() as u64) as u8;
            let calculated = if is_backup_running {
                avg.min(99).max(1)
            } else {
                avg
            };
            let pct = std::cmp::max(last_folder_pct, calculated);
            (
                TransferState::Uploading,
                FileLocation::Local,
                pct,
                format!(
                    "Enviando arquivos internos (:5577) - {} ativa(s)...",
                    matching.len()
                ),
            )
        } else if is_backup_running {
            if last_folder_pct > 0 && last_folder_pct < 100 {
                (
                    TransferState::Aguardando,
                    FileLocation::Local,
                    last_folder_pct,
                    "Arquivos internos na fila de envio (:5577)...".to_string(),
                )
            } else if !exists_on_remote {
                (
                    TransferState::Aguardando,
                    FileLocation::Local,
                    0,
                    "Pasta aguardando início do upload (:5577)".to_string(),
                )
            } else {
                (
                    TransferState::Aguardando,
                    FileLocation::Local,
                    0,
                    "Pasta na fila de sincronização (:5577)...".to_string(),
                )
            }
        } else if !exists_on_remote {
            (
                TransferState::Aguardando,
                FileLocation::Local,
                0,
                "Pasta aguardando início do upload (:5577)".to_string(),
            )
        } else {
            (
                TransferState::Uploaded,
                FileLocation::Ambos,
                100,
                "Sincronizado".to_string(),
            )
        }
    }
}

pub fn has_queued_entries_under(
    clean_rel: &str,
    queue: &[UploadQueueItem],
    vfs_uploading: &[String],
    vfs_queued: &[String],
) -> bool {
    let target = normalize_rel_path(clean_rel);
    if target.is_empty() {
        return true;
    }
    let prefix = format!("{}/", target);
    queue.iter().any(|it| {
        let d = normalize_rel_path(&it.target_rel_dir);
        d == target || d.starts_with(&prefix)
    }) || vfs_uploading.iter().chain(vfs_queued.iter()).any(|v| {
        let c = normalize_rel_path(v);
        c.starts_with(&prefix)
    })
}

fn systemd_status(unit: &str) -> bool {
    let output = Command::new("systemctl")
        .args(["--user", "is-active", unit])
        .output();
    match output {
        Ok(out) => {
            let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
            s == "active" || s == "activating"
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

fn child_segment<'a>(clean_rel: &str, target_rel: &'a str) -> Option<&'a str> {
    let t = target_rel.trim_matches('/');
    if clean_rel.is_empty() {
        if t.is_empty() {
            None
        } else {
            t.split('/').next().filter(|s| !s.is_empty())
        }
    } else {
        let prefix = format!("{}/", clean_rel);
        t.strip_prefix(&prefix)
            .and_then(|rest| rest.split('/').next())
            .filter(|s| !s.is_empty())
    }
}

pub fn merge_queue_and_transfers(
    clean_rel: &str,
    items: &mut Vec<DriveItem>,
    queue: &[UploadQueueItem],
    vfs_uploading: &[String],
    vfs_queued: &[String],
) {
    // 1. Apply VFS queue paths (relative to ~/GoogleDrive) to files and parent folders
    for vfs_rel in vfs_uploading {
        let clean_vfs = normalize_rel_path(vfs_rel);
        let (parent_dir, file_name) = match clean_vfs.rfind('/') {
            Some(idx) => (&clean_vfs[..idx], &clean_vfs[idx + 1..]),
            None => ("", clean_vfs.as_str()),
        };
        if parent_dir == clean_rel {
            if let Some(existing) = items.iter_mut().find(|i| i.name == file_name) {
                existing.sync_state = TransferState::Uploading;
                existing.location = FileLocation::Local;
                if existing.progress_percent == 100 || existing.progress_percent == 0 {
                    existing.progress_percent = 50;
                }
                existing.status_note = "Enviando para nuvem (VFS)...".to_string();
            } else if !file_name.is_empty() {
                items.push(DriveItem {
                    name: file_name.to_string(),
                    rel_path: if clean_rel.is_empty() {
                        file_name.to_string()
                    } else {
                        format!("{}/{}", clean_rel, file_name)
                    },
                    is_dir: false,
                    size: 0,
                    modified_ts: 0,
                    modified_str: "-".to_string(),
                    location: FileLocation::Local,
                    sync_state: TransferState::Uploading,
                    progress_percent: 50,
                    status_note: "Enviando para nuvem (VFS)...".to_string(),
                });
            }
        } else if let Some(child_dir) = child_segment(clean_rel, &clean_vfs) {
            if child_dir != file_name || !parent_dir.is_empty() {
                if let Some(existing) = items.iter_mut().find(|i| i.is_dir && i.name == child_dir) {
                    existing.sync_state = TransferState::Uploading;
                    existing.location = FileLocation::Local;
                    if existing.progress_percent == 100 || existing.progress_percent == 0 {
                        existing.progress_percent = 50;
                    }
                    existing.status_note = "Enviando arquivos internos (VFS)...".to_string();
                } else {
                    items.push(DriveItem {
                        name: child_dir.to_string(),
                        rel_path: if clean_rel.is_empty() {
                            child_dir.to_string()
                        } else {
                            format!("{}/{}", clean_rel, child_dir)
                        },
                        is_dir: true,
                        size: 0,
                        modified_ts: 0,
                        modified_str: "-".to_string(),
                        location: FileLocation::Local,
                        sync_state: TransferState::Uploading,
                        progress_percent: 50,
                        status_note: "Enviando arquivos internos (VFS)...".to_string(),
                    });
                }
            }
        }
    }

    for vfs_rel in vfs_queued {
        let clean_vfs = normalize_rel_path(vfs_rel);
        let (parent_dir, file_name) = match clean_vfs.rfind('/') {
            Some(idx) => (&clean_vfs[..idx], &clean_vfs[idx + 1..]),
            None => ("", clean_vfs.as_str()),
        };
        if parent_dir == clean_rel {
            if let Some(existing) = items.iter_mut().find(|i| i.name == file_name) {
                if existing.sync_state != TransferState::Uploading {
                    existing.sync_state = TransferState::Aguardando;
                    existing.location = FileLocation::Local;
                    existing.progress_percent = 0;
                    existing.status_note = "Na fila de envio VFS".to_string();
                }
            } else if !file_name.is_empty() {
                items.push(DriveItem {
                    name: file_name.to_string(),
                    rel_path: if clean_rel.is_empty() {
                        file_name.to_string()
                    } else {
                        format!("{}/{}", clean_rel, file_name)
                    },
                    is_dir: false,
                    size: 0,
                    modified_ts: 0,
                    modified_str: "-".to_string(),
                    location: FileLocation::Local,
                    sync_state: TransferState::Aguardando,
                    progress_percent: 0,
                    status_note: "Na fila de envio VFS".to_string(),
                });
            }
        } else if let Some(child_dir) = child_segment(clean_rel, &clean_vfs) {
            if child_dir != file_name || !parent_dir.is_empty() {
                if let Some(existing) = items.iter_mut().find(|i| i.is_dir && i.name == child_dir) {
                    if existing.sync_state == TransferState::Uploaded {
                        existing.sync_state = TransferState::Aguardando;
                        existing.location = FileLocation::Local;
                        existing.progress_percent = 0;
                        existing.status_note = "Arquivos internos na fila VFS".to_string();
                    }
                } else {
                    items.push(DriveItem {
                        name: child_dir.to_string(),
                        rel_path: if clean_rel.is_empty() {
                            child_dir.to_string()
                        } else {
                            format!("{}/{}", clean_rel, child_dir)
                        },
                        is_dir: true,
                        size: 0,
                        modified_ts: 0,
                        modified_str: "-".to_string(),
                        location: FileLocation::Local,
                        sync_state: TransferState::Aguardando,
                        progress_percent: 0,
                        status_note: "Arquivos internos na fila VFS".to_string(),
                    });
                }
            }
        }
    }

    // 2. Direct files in clean_rel from app upload queue
    for it in queue.iter() {
        let target_dir_clean = normalize_rel_path(&it.target_rel_dir);
        if target_dir_clean == clean_rel {
            let pct = if it.state == TransferState::Uploaded {
                100
            } else if it.size > 0 {
                ((it.transferred_bytes * 100) / it.size).min(99) as u8
            } else if it.state == TransferState::Uploading {
                50
            } else {
                0
            };

            if let Some(existing) = items.iter_mut().find(|i| i.name == it.target_name) {
                if it.state == TransferState::Uploaded {
                    if existing.sync_state == TransferState::Uploaded {
                        existing.location = FileLocation::Ambos;
                        existing.progress_percent = 100;
                    }
                } else {
                    existing.location = FileLocation::Local;
                    existing.sync_state = it.state.clone();
                    existing.progress_percent = pct;
                    existing.status_note = "Na fila de upload local".to_string();
                }
            } else {
                let is_done = it.state == TransferState::Uploaded;
                items.push(DriveItem {
                    name: it.target_name.clone(),
                    rel_path: if clean_rel.is_empty() {
                        it.target_name.clone()
                    } else {
                        format!("{}/{}", clean_rel, it.target_name)
                    },
                    is_dir: false,
                    size: it.size,
                    modified_ts: it.updated_ts,
                    modified_str: format_timestamp(it.updated_ts),
                    location: if is_done { FileLocation::Ambos } else { FileLocation::Local },
                    sync_state: it.state.clone(),
                    progress_percent: pct,
                    status_note: if is_done {
                        "Sincronizado".to_string()
                    } else {
                        "Na fila de upload local".to_string()
                    },
                });
            }
        }
    }

    // 3. Synthesize and aggregate child folders from app upload queue
    let mut child_folders: Vec<String> = Vec::new();
    for it in queue.iter() {
        let norm_target = normalize_rel_path(&it.target_rel_dir);
        if let Some(seg) = child_segment(clean_rel, &norm_target) {
            if !child_folders.iter().any(|c| c == seg) {
                child_folders.push(seg.to_string());
            }
        }
    }

    for folder_name in child_folders {
        let group: Vec<&UploadQueueItem> = queue
            .iter()
            .filter(|it| {
                let norm_target = normalize_rel_path(&it.target_rel_dir);
                child_segment(clean_rel, &norm_target) == Some(folder_name.as_str())
            })
            .collect();

        if group.is_empty() {
            continue;
        }

        let total_bytes: u64 = group.iter().map(|i| i.size).sum();
        let trans_bytes: u64 = group
            .iter()
            .map(|i| {
                if i.state == TransferState::Uploaded {
                    i.size
                } else {
                    i.transferred_bytes
                }
            })
            .sum();

        let any_uploading = group.iter().any(|i| i.state == TransferState::Uploading);
        let any_waiting = group.iter().any(|i| i.state == TransferState::Aguardando);
        let any_uploaded = group.iter().any(|i| i.state == TransferState::Uploaded);
        let any_error = group.iter().any(|i| i.state == TransferState::Error);
        let waiting_count = group
            .iter()
            .filter(|i| i.state == TransferState::Aguardando)
            .count();
        let latest_ts = group.iter().map(|i| i.updated_ts).max().unwrap_or(0);

        let (sync_state, location, pct, note) = if any_uploading || (any_uploaded && any_waiting) {
            let p = if total_bytes > 0 {
                ((trans_bytes * 100) / total_bytes).min(99) as u8
            } else {
                50
            };
            let msg = if waiting_count > 0 {
                format!("Enviando arquivos da pasta ({} aguardando)...", waiting_count)
            } else {
                "Enviando arquivos da pasta...".to_string()
            };
            (TransferState::Uploading, FileLocation::Local, p, msg)
        } else if any_waiting {
            (
                TransferState::Aguardando,
                FileLocation::Local,
                0,
                "Pasta na fila de upload (aguardando início)".to_string(),
            )
        } else if any_error {
            (
                TransferState::Error,
                FileLocation::Local,
                0,
                "Erro em arquivos da pasta".to_string(),
            )
        } else {
            (
                TransferState::Uploaded,
                FileLocation::Ambos,
                100,
                "Sincronizado".to_string(),
            )
        };

        let folder_rel = if clean_rel.is_empty() {
            folder_name.clone()
        } else {
            format!("{}/{}", clean_rel, folder_name)
        };

        if let Some(existing) = items.iter_mut().find(|i| i.name == folder_name) {
            if sync_state != TransferState::Uploaded {
                existing.sync_state = sync_state;
                existing.location = location;
                existing.progress_percent = pct;
                existing.status_note = note;
            }
        } else {
            items.push(DriveItem {
                name: folder_name,
                rel_path: folder_rel,
                is_dir: true,
                size: 0,
                modified_ts: latest_ts,
                modified_str: format_timestamp(latest_ts),
                location,
                sync_state,
                progress_percent: pct,
                status_note: note,
            });
        }
    }
}

// ----------------------------------------------------------------------------
// TAURI COMMANDS
// ----------------------------------------------------------------------------

#[tauri::command]
fn list_directory(rel_path: String, state: State<AppState>) -> Result<Vec<DriveItem>, String> {
    let dir_path = sanitize_rel_path(&rel_path)?;
    let clean_rel = normalize_rel_path(&rel_path);
    let in_backup_tree = is_protected_backup_path(&clean_rel);

    // Query VFS queue on 5576 (full relative paths inside ~/GoogleDrive)
    let mut vfs_queued: Vec<String> = Vec::new();
    let mut vfs_uploading: Vec<String> = Vec::new();

    if !in_backup_tree {
        if let Some(val) = query_rc(5576, "vfs/queue") {
            if let Some(arr) = val.get("queue").and_then(|q| q.as_array()) {
                for q_item in arr {
                    let name = q_item.get("name").and_then(|n| n.as_str()).unwrap_or("");
                    let is_uploading = q_item
                        .get("uploading")
                        .and_then(|u| u.as_bool())
                        .unwrap_or(false);
                    if !name.is_empty() {
                        if is_uploading {
                            vfs_uploading.push(name.trim_matches('/').to_string());
                        } else {
                            vfs_queued.push(name.trim_matches('/').to_string());
                        }
                    }
                }
            }
        }
        if let Some(stats) = query_rc(5576, "core/stats") {
            if let Some(arr) = stats.get("transferring").and_then(|t| t.as_array()) {
                for t in arr {
                    if let Some(name) = t.get("name").and_then(|n| n.as_str()) {
                        let clean_name = name.trim_matches('/').to_string();
                        if !clean_name.is_empty() && !vfs_uploading.contains(&clean_name) {
                            vfs_uploading.push(clean_name);
                        }
                    }
                }
            }
        }
    }

    if !dir_path.exists() {
        let has_virtual = if !in_backup_tree {
            let q = state.queue.lock().unwrap();
            has_queued_entries_under(&clean_rel, &q, &vfs_uploading, &vfs_queued)
        } else {
            false
        };
        if !has_virtual {
            return Err(format!("Diretório não encontrado: {}", dir_path.display()));
        }
    }

    // Query 5577 Backup active transfers when at root or inside Backup-SanDisk-1TB
    let mut backup_transfers_rel: Vec<(String, u8)> = Vec::new();
    let mut backup_bytes = 0u64;
    let mut backup_total_bytes = 0u64;
    let mut backup_transfers = 0u64;
    let mut backup_total_transfers = 0u64;

    let backup_running = if clean_rel.is_empty() || in_backup_tree {
        if let Some(stats) = query_rc(5577, "core/stats") {
            backup_bytes = stats.get("bytes").and_then(|v| v.as_u64()).unwrap_or(0);
            backup_total_bytes = stats.get("totalBytes").and_then(|v| v.as_u64()).unwrap_or(0);
            backup_transfers = stats.get("transfers").and_then(|v| v.as_u64()).unwrap_or(0);
            backup_total_transfers = stats.get("totalTransfers").and_then(|v| v.as_u64()).unwrap_or(0);

            if let Some(arr) = stats.get("transferring").and_then(|t| t.as_array()) {
                for t in arr {
                    let name = t
                        .get("name")
                        .and_then(|n| n.as_str())
                        .unwrap_or("")
                        .trim_matches('/')
                        .to_string();
                    let pct = t.get("percentage").and_then(|p| p.as_u64()).unwrap_or(50) as u8;
                    if !name.is_empty() {
                        backup_transfers_rel.push((name, pct));
                    }
                }
            }
            true
        } else {
            systemd_status("rclone-backup.service")
        }
    } else {
        false
    };

    let backup_remote_names = if in_backup_tree {
        let sub_dir = clean_rel
            .strip_prefix("Backup-SanDisk-1TB")
            .unwrap_or("")
            .trim_matches('/');
        fetch_backup_remote_names(sub_dir, &state.backup_remote_cache)
    } else {
        None
    };

    let mut items = Vec::new();

    if dir_path.exists() {
        let entries = fs::read_dir(&dir_path)
            .map_err(|e| format!("Erro ao ler diretório {}: {}", dir_path.display(), e))?;

        for entry_res in entries {
            let entry = match entry_res {
                Ok(e) => e,
                Err(_) => continue,
            };
            let file_name = entry.file_name().to_string_lossy().to_string();
            // Skip hidden FUSE metadata or excluded system folders on SanDisk SSD
            if file_name.starts_with(".fuse_hidden")
                || (in_backup_tree
                    && (file_name.ends_with("RECYCLE.BIN") || file_name == ".Trash-1000"))
            {
                continue;
            }

            let meta = entry.metadata().ok();
            let is_dir = meta.as_ref().map(|m| m.is_dir()).unwrap_or(false);
            let size = if is_dir {
                0
            } else {
                meta.as_ref().map(|m| m.len()).unwrap_or(0)
            };

            let mod_ts = meta
                .as_ref()
                .and_then(|m| m.modified().ok())
                .and_then(|st| st.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_secs())
                .unwrap_or(0);

            let item_rel = if clean_rel.is_empty() {
                file_name.clone()
            } else {
                format!("{}/{}", clean_rel, file_name)
            };

            let (sync_state, location, progress, note) = if in_backup_tree {
                let sub_rel = item_rel
                    .strip_prefix("Backup-SanDisk-1TB/")
                    .unwrap_or(&file_name);
                let last_p = if is_dir {
                    let guard = state.folder_progress_cache.lock().unwrap();
                    guard.get(&item_rel).copied().unwrap_or(0)
                } else {
                    0
                };
                let res = resolve_backup_item_state(
                    sub_rel,
                    &file_name,
                    is_dir,
                    &backup_transfers_rel,
                    backup_remote_names.as_deref(),
                    backup_running,
                    last_p,
                );
                if is_dir && (res.0 == TransferState::Uploading || res.0 == TransferState::Aguardando) && res.2 > 0 {
                    let mut guard = state.folder_progress_cache.lock().unwrap();
                    guard.insert(item_rel.clone(), res.2);
                }
                res
            } else if is_dir {
                (
                    TransferState::Uploaded,
                    FileLocation::Ambos,
                    100,
                    "Sincronizado".to_string(),
                )
            } else if is_in_vfs_cache(&item_rel) {
                (
                    TransferState::Uploaded,
                    FileLocation::Ambos,
                    100,
                    "Sincronizado".to_string(),
                )
            } else {
                (
                    TransferState::Uploaded,
                    FileLocation::Nuvem,
                    100,
                    "Sincronizado".to_string(),
                )
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
    }

    // Project Backup-SanDisk-1TB inside ~/GoogleDrive root
    if clean_rel.is_empty() && !items.iter().any(|i| i.name == "Backup-SanDisk-1TB") {
        let sandisk_path = Path::new("/mnt/sandisk");
        if sandisk_path.exists() || backup_running {
            let mod_ts = fs::metadata(sandisk_path)
                .ok()
                .and_then(|m| m.modified().ok())
                .and_then(|st| st.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_secs())
                .unwrap_or(0);

            let last_root_pct = {
                let guard = state.folder_progress_cache.lock().unwrap();
                guard.get("Backup-SanDisk-1TB").copied().unwrap_or(0)
            };

            let (b_state, b_pct, b_note) = calculate_backup_root_progress(
                backup_bytes,
                backup_total_bytes,
                backup_transfers,
                backup_total_transfers,
                backup_transfers_rel.len(),
                last_root_pct,
                backup_running,
            );

            {
                let mut guard = state.folder_progress_cache.lock().unwrap();
                guard.insert("Backup-SanDisk-1TB".to_string(), b_pct);
            }

            items.push(DriveItem {
                name: "Backup-SanDisk-1TB".to_string(),
                rel_path: "Backup-SanDisk-1TB".to_string(),
                is_dir: true,
                size: 0,
                modified_ts: mod_ts,
                modified_str: format_timestamp(mod_ts),
                location: FileLocation::Ambos,
                sync_state: b_state,
                progress_percent: b_pct,
                status_note: b_note,
            });
        }
    }

    // Merge items and synthesized folders from app upload queue and VFS queue
    if !in_backup_tree {
        let q = state.queue.lock().unwrap();
        merge_queue_and_transfers(&clean_rel, &mut items, &q, &vfs_uploading, &vfs_queued);
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
fn preview_file(rel_path: String, state: State<AppState>) -> Result<PreviewResult, String> {
    let mut path = sanitize_rel_path(&rel_path)?;
    if !path.exists() {
        let clean_rel = normalize_rel_path(&rel_path);
        let q = state.queue.lock().unwrap();
        let queued_src = q.iter().find_map(|it| {
            let dir = normalize_rel_path(&it.target_rel_dir);
            let item_rel = if dir.is_empty() {
                it.target_name.clone()
            } else {
                format!("{}/{}", dir, it.target_name)
            };
            if item_rel == clean_rel {
                Some(PathBuf::from(&it.source_path))
            } else {
                None
            }
        });
        if let Some(src_path) = queued_src {
            if src_path.exists() {
                path = src_path;
            }
        }
        if !path.exists() {
            return Err("Arquivo não encontrado".to_string());
        }
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
        content = format!("Diretório do Google Drive ({})", path.display());
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
    if is_protected_backup_path(&rel_path) {
        return Err("Pasta gerenciada pelo rclone-backup (somente leitura)".to_string());
    }
    let clean_name = folder_name.trim();
    if clean_name.is_empty() || clean_name.contains('/') || clean_name.contains("..") {
        return Err("Nome de pasta inválido".to_string());
    }
    let parent = sanitize_rel_path(&rel_path)?;
    let target = parent.join(clean_name);
    fs::create_dir_all(&target).map_err(|e| format!("Erro ao criar pasta: {}", e))?;
    Ok(())
}

#[tauri::command]
fn rename_entry(rel_path: String, new_name: String) -> Result<(), String> {
    if is_protected_backup_path(&rel_path) {
        return Err("Não é permitido renomear itens do Backup-SanDisk-1TB".to_string());
    }
    let clean_new = new_name.trim();
    if clean_new.is_empty() || clean_new.contains('/') || clean_new.contains("..") {
        return Err("Novo nome inválido".to_string());
    }
    let source = sanitize_rel_path(&rel_path)?;
    if source == gdrive_root() {
        return Err("Não é permitido renomear a raiz do Google Drive".to_string());
    }
    let parent = source.parent().ok_or("Diretório pai inválido")?;
    let target = parent.join(clean_new);
    fs::rename(&source, &target).map_err(|e| format!("Erro ao renomear: {}", e))?;
    Ok(())
}

#[tauri::command]
fn delete_entry(rel_path: String) -> Result<(), String> {
    if is_protected_backup_path(&rel_path) {
        return Err("Não é permitido excluir itens do Backup-SanDisk-1TB".to_string());
    }
    let target = sanitize_rel_path(&rel_path)?;
    if target == gdrive_root() {
        return Err("Não é permitido excluir a raiz do Google Drive".to_string());
    }
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
    let target = sanitize_rel_path(&rel_path)?;
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
    if is_protected_backup_path(&target_rel_dir) {
        return Err("Destino Backup-SanDisk-1TB é gerenciado automaticamente pelo rclone-backup".to_string());
    }
    let clean_target = normalize_rel_path(&target_rel_dir);
    let target_dir = sanitize_rel_path(&clean_target)?;
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

            let folder_target_rel = if clean_target.is_empty() {
                folder_name.clone()
            } else {
                format!("{}/{}", clean_target, folder_name)
            };
            if let Ok(d) = sanitize_rel_path(&folder_target_rel) {
                let _ = fs::create_dir_all(&d);
            }

            let mut files = Vec::new();
            collect_folder_files(&src_path, &src_path, &mut files);

            if !files.is_empty() {
                for (file_path, rel_sub, f_size) in files {
                    let file_name = file_path
                        .file_name()
                        .map(|f| f.to_string_lossy().to_string())
                        .unwrap_or_else(|| "arquivo".to_string());

                    let rel_parent = Path::new(&rel_sub)
                        .parent()
                        .map(|p| p.to_string_lossy().to_string())
                        .unwrap_or_default();

                    let item_target_rel = if clean_target.is_empty() {
                        if rel_parent.is_empty() {
                            folder_name.clone()
                        } else {
                            format!("{}/{}", folder_name, rel_parent)
                        }
                    } else if rel_parent.is_empty() {
                        format!("{}/{}", clean_target, folder_name)
                    } else {
                        format!("{}/{}/{}", clean_target, folder_name, rel_parent)
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
            let parent = if clean_target.is_empty() {
                None
            } else {
                Some(clean_target.clone())
            };
            let item = UploadQueueItem {
                id,
                source_path: src_str,
                target_rel_dir: clean_target.clone(),
                target_name: name,
                size,
                transferred_bytes: 0,
                state: TransferState::Aguardando,
                error_message: None,
                created_ts: now,
                updated_ts: now,
                parent_folder: parent,
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
    retain_incomplete_queue(&mut q);
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

    if let Some(vq) = query_rc(5576, "vfs/queue") {
        if let Some(arr) = vq.get("queue").and_then(|q| q.as_array()) {
            for q_item in arr {
                let name = q_item.get("name").and_then(|n| n.as_str()).unwrap_or("");
                let is_uploading = q_item
                    .get("uploading")
                    .and_then(|u| u.as_bool())
                    .unwrap_or(false);
                let size = q_item.get("size").and_then(|s| s.as_u64()).unwrap_or(0);
                if !name.is_empty()
                    && !is_uploading
                    && !mount_transfers.iter().any(|m| m.name == name)
                {
                    mount_transfers.push(ActiveTransfer {
                        name: name.to_string(),
                        percentage: 0,
                        bytes: 0,
                        size,
                        speed_avg: 0.0,
                        eta: None,
                        source: "Fila VFS (Aguardando)".to_string(),
                    });
                }
            }
        }
    }

    // Query 5577 Backup Stats
    let mut backup_transfers = Vec::new();
    let mut last_synced_files = Vec::new();
    let mut backup_stats = None;

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

        let total_transfers = stats
            .get("totalTransfers")
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
        let done_transfers = stats.get("transfers").and_then(|v| v.as_u64()).unwrap_or(0);
        let active_len = backup_transfers.len() as u64;
        let pending_count = total_transfers.saturating_sub(done_transfers + active_len);

        let total_bytes = stats
            .get("totalBytes")
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
        let done_bytes = stats.get("bytes").and_then(|v| v.as_u64()).unwrap_or(0);
        let pending_bytes = total_bytes.saturating_sub(done_bytes);

        let speed = stats.get("speed").and_then(|s| s.as_f64()).unwrap_or(0.0);
        let eta = stats.get("eta").and_then(|e| e.as_u64());
        let errors = stats.get("errors").and_then(|e| e.as_u64()).unwrap_or(0);

        let last_root_pct = {
            let guard = state.folder_progress_cache.lock().unwrap();
            guard.get("Backup-SanDisk-1TB").copied().unwrap_or(0)
        };

        let calculated_pct = if total_bytes > 0 {
            ((done_bytes * 100) / total_bytes).min(99) as u8
        } else if total_transfers > 0 {
            ((done_transfers * 100) / total_transfers).min(99) as u8
        } else if !backup_transfers.is_empty() {
            1
        } else {
            0
        };
        let percentage = std::cmp::max(last_root_pct, calculated_pct);

        backup_stats = Some(BackupStats {
            is_active: backup_active || !backup_transfers.is_empty(),
            bytes: done_bytes,
            total_bytes,
            transfers_done: done_transfers,
            total_transfers,
            pending_transfers: pending_count,
            pending_bytes,
            active_count: backup_transfers.len(),
            speed,
            eta,
            errors,
            percentage,
        });
    } else if backup_active {
        backup_stats = Some(BackupStats {
            is_active: true,
            bytes: 0,
            total_bytes: 0,
            transfers_done: 0,
            total_transfers: 0,
            pending_transfers: 0,
            pending_bytes: 0,
            active_count: 0,
            speed: 0.0,
            eta: None,
            errors: 0,
            percentage: 0,
        });
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
        backup_stats,
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
        backup_remote_cache: Arc::new(Mutex::new(std::collections::HashMap::new())),
        folder_progress_cache: Arc::new(Mutex::new(std::collections::HashMap::new())),
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
    use super::{
        base64_light, chrono_light, gdrive_root, guess_mime, is_protected_backup_path,
        merge_queue_and_transfers, normalize_rel_path, sanitize_rel_path, DriveItem, FileLocation,
        TransferState, UploadQueueItem,
    };
    use std::path::PathBuf;

    #[test]
    fn test_sanitize_rel_path() {
        let root = gdrive_root();
        assert_eq!(sanitize_rel_path("").unwrap(), root);
        assert_eq!(sanitize_rel_path("/").unwrap(), root);
        assert_eq!(sanitize_rel_path("GoogleDrive").unwrap(), root);
        assert_eq!(sanitize_rel_path("GoogleDrive/Docs").unwrap(), root.join("Docs"));
        assert_eq!(sanitize_rel_path("Docs").unwrap(), root.join("Docs"));
        assert_eq!(sanitize_rel_path("/Docs/Pessoais/").unwrap(), root.join("Docs/Pessoais"));
        assert_eq!(
            sanitize_rel_path("Backup-SanDisk-1TB").unwrap(),
            PathBuf::from("/mnt/sandisk")
        );
        assert_eq!(
            sanitize_rel_path("Backup-SanDisk-1TB/Downloads").unwrap(),
            PathBuf::from("/mnt/sandisk/Downloads")
        );
        assert_eq!(normalize_rel_path("GoogleDrive/Pasta"), "Pasta");
        assert!(is_protected_backup_path("Backup-SanDisk-1TB"));
        assert!(is_protected_backup_path("/Backup-SanDisk-1TB/Downloads"));
        assert!(!is_protected_backup_path("Docs"));
        assert!(sanitize_rel_path("../etc/passwd").is_err());
        assert!(sanitize_rel_path("Docs/../../root").is_err());
    }

    #[test]
    fn test_merge_queue_synthesizes_folders_and_files() {
        let queue = vec![
            UploadQueueItem {
                id: "1".into(),
                source_path: "/tmp/ProjetoX/src/main.rs".into(),
                target_rel_dir: "ProjetoX/src".into(),
                target_name: "main.rs".into(),
                size: 1000,
                transferred_bytes: 500,
                state: TransferState::Uploading,
                error_message: None,
                created_ts: 1700000000,
                updated_ts: 1700000005,
                parent_folder: Some("ProjetoX".into()),
                rel_file_path: Some("src/main.rs".into()),
            },
            UploadQueueItem {
                id: "2".into(),
                source_path: "/tmp/ProjetoX/README.md".into(),
                target_rel_dir: "ProjetoX".into(),
                target_name: "README.md".into(),
                size: 500,
                transferred_bytes: 0,
                state: TransferState::Aguardando,
                error_message: None,
                created_ts: 1700000000,
                updated_ts: 1700000000,
                parent_folder: Some("ProjetoX".into()),
                rel_file_path: Some("README.md".into()),
            },
        ];

        // 1. At root (""): should synthesize folder "ProjetoX" as Uploading (500/1500 = 33%)
        let mut root_items: Vec<DriveItem> = Vec::new();
        merge_queue_and_transfers("", &mut root_items, &queue, &[], &[]);
        assert_eq!(root_items.len(), 1);
        assert_eq!(root_items[0].name, "ProjetoX");
        assert_eq!(root_items[0].rel_path, "ProjetoX");
        assert!(root_items[0].is_dir);
        assert_eq!(root_items[0].sync_state, TransferState::Uploading);
        assert_eq!(root_items[0].location, FileLocation::Local);
        assert_eq!(root_items[0].progress_percent, 33);

        // 2. Inside "ProjetoX": should synthesize subfolder "src" and file "README.md"
        let mut proj_items: Vec<DriveItem> = Vec::new();
        merge_queue_and_transfers("ProjetoX", &mut proj_items, &queue, &[], &[]);
        assert_eq!(proj_items.len(), 2);
        let src_dir = proj_items.iter().find(|i| i.name == "src").unwrap();
        assert!(src_dir.is_dir);
        assert_eq!(src_dir.rel_path, "ProjetoX/src");
        assert_eq!(src_dir.sync_state, TransferState::Uploading);

        let readme = proj_items.iter().find(|i| i.name == "README.md").unwrap();
        assert!(!readme.is_dir);
        assert_eq!(readme.rel_path, "ProjetoX/README.md");
        assert_eq!(readme.sync_state, TransferState::Aguardando);
    }

    #[test]
    fn test_merge_vfs_propagates_to_existing_folder() {
        let mut items = vec![DriveItem {
            name: "Videos".into(),
            rel_path: "Videos".into(),
            is_dir: true,
            size: 0,
            modified_ts: 1700000000,
            modified_str: "-".into(),
            location: FileLocation::Ambos,
            sync_state: TransferState::Uploaded,
            progress_percent: 100,
            status_note: "Sincronizado".into(),
        }];

        let vfs_uploading = vec!["Videos/aula1.mp4".to_string()];
        merge_queue_and_transfers("", &mut items, &[], &vfs_uploading, &[]);
        assert_eq!(items[0].sync_state, TransferState::Uploading);
        assert_eq!(items[0].location, FileLocation::Local);
    }

    #[test]
    fn test_vfs_queued_synthesizes_missing_files_and_folders() {
        let mut items: Vec<DriveItem> = Vec::new();
        let vfs_queued = vec![
            "nota_pendente.txt".to_string(),
            "Relatorios/2026/abril.pdf".to_string(),
        ];
        merge_queue_and_transfers("", &mut items, &[], &[], &vfs_queued);

        let file_item = items.iter().find(|i| i.name == "nota_pendente.txt").expect("should synthesize queued VFS file");
        assert!(!file_item.is_dir);
        assert_eq!(file_item.sync_state, TransferState::Aguardando);
        assert_eq!(file_item.location, FileLocation::Local);

        let dir_item = items.iter().find(|i| i.name == "Relatorios").expect("should synthesize queued VFS parent folder");
        assert!(dir_item.is_dir);
        assert_eq!(dir_item.sync_state, TransferState::Aguardando);
        assert_eq!(dir_item.location, FileLocation::Local);
    }

    #[test]
    fn test_has_queued_entries_under_virtual_subfolder() {
        let queue = vec![UploadQueueItem {
            id: "1".into(),
            source_path: "/tmp/Curso/Modulo1/aula.mp4".into(),
            target_rel_dir: "Curso/Modulo1".into(),
            target_name: "aula.mp4".into(),
            size: 1024,
            transferred_bytes: 0,
            state: TransferState::Aguardando,
            error_message: None,
            created_ts: 1700000000,
            updated_ts: 1700000000,
            parent_folder: Some("Curso".into()),
            rel_file_path: Some("Modulo1/aula.mp4".into()),
        }];

        assert!(super::has_queued_entries_under("Curso", &queue, &[], &[]));
        assert!(super::has_queued_entries_under("Curso/Modulo1", &queue, &[], &[]));
        assert!(!super::has_queued_entries_under("OutraPasta", &queue, &[], &[]));
    }

    #[test]
    fn test_resolve_backup_item_state_shows_aguardando_when_not_on_remote() {
        let active_transfers = vec![("Downloads/ativo.zip".to_string(), 45u8)];
        let remote_names = vec!["ja_sincronizado.txt".to_string(), "PastaSincronizada".to_string()];

        // 1. File not on remote and not transferring -> Aguardando + Local
        let (st1, loc1, pct1, _) = super::resolve_backup_item_state(
            "Downloads/aguardando.zip",
            "aguardando.zip",
            false,
            &active_transfers,
            Some(&remote_names),
            true,
            0,
        );
        assert_eq!(st1, TransferState::Aguardando);
        assert_eq!(loc1, FileLocation::Local);
        assert_eq!(pct1, 0);

        // 2. File actively transferring -> Uploading + Local
        let (st2, loc2, pct2, _) = super::resolve_backup_item_state(
            "Downloads/ativo.zip",
            "ativo.zip",
            false,
            &active_transfers,
            Some(&remote_names),
            true,
            0,
        );
        assert_eq!(st2, TransferState::Uploading);
        assert_eq!(loc2, FileLocation::Local);
        assert_eq!(pct2, 45);

        // 3. File already on remote -> Uploaded + Ambos
        let (st3, loc3, pct3, _) = super::resolve_backup_item_state(
            "Downloads/ja_sincronizado.txt",
            "ja_sincronizado.txt",
            false,
            &active_transfers,
            Some(&remote_names),
            true,
            0,
        );
        assert_eq!(st3, TransferState::Uploaded);
        assert_eq!(loc3, FileLocation::Ambos);
        assert_eq!(pct3, 100);

        // 4. Folder that was previously uploading stays in Aguardando with preserved pct, does not jump to Uploaded 100% while backup is running
        let (st4, _, pct4, note4) = super::resolve_backup_item_state(
            "Downloads/MinhaPasta",
            "MinhaPasta",
            true,
            &[], // no active transfers right now in this folder
            Some(&["MinhaPasta".to_string()]),
            true, // backup is running
            50, // last folder pct was 50%
        );
        assert_eq!(st4, TransferState::Aguardando);
        assert_eq!(pct4, 50);
        assert!(note4.contains("fila de envio"));
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

    #[test]
    fn test_calculate_backup_root_progress_uses_total_stats() {
        // total_bytes: 10GB, bytes: 9.5GB -> 95%, not 25% or average of active transfers
        let (state, pct, note) = super::calculate_backup_root_progress(
            9_500_000_000,
            10_000_000_000,
            250_000,
            260_000,
            4,
            0,
            true,
        );
        assert_eq!(state, TransferState::Uploading);
        assert_eq!(pct, 95);
        assert!(note.contains("95%"));

        // Monotonic guarantee: if total_bytes temporarily glitches, progress never drops below last_progress
        let (_, pct_glitch, _) = super::calculate_backup_root_progress(
            1_000,
            10_000_000_000,
            1,
            260_000,
            1,
            95,
            true,
        );
        assert_eq!(pct_glitch, 95);

        // When backup finishes
        let (state_done, pct_done, _) = super::calculate_backup_root_progress(
            10_000_000_000,
            10_000_000_000,
            260_000,
            260_000,
            0,
            95,
            false,
        );
        assert_eq!(state_done, TransferState::Uploaded);
        assert_eq!(pct_done, 100);
    }

    #[test]
    fn test_filter_completed_uploads_preserves_incomplete_folders() {
        let mut queue = vec![
            UploadQueueItem {
                id: "1".into(),
                source_path: "/tmp/A/1.txt".into(),
                target_rel_dir: "A".into(),
                target_name: "1.txt".into(),
                size: 100,
                transferred_bytes: 100,
                state: TransferState::Uploaded,
                error_message: None,
                created_ts: 1,
                updated_ts: 1,
                parent_folder: Some("A".into()),
                rel_file_path: Some("1.txt".into()),
            },
            UploadQueueItem {
                id: "2".into(),
                source_path: "/tmp/A/2.txt".into(),
                target_rel_dir: "A".into(),
                target_name: "2.txt".into(),
                size: 100,
                transferred_bytes: 0,
                state: TransferState::Aguardando,
                error_message: None,
                created_ts: 1,
                updated_ts: 1,
                parent_folder: Some("A".into()),
                rel_file_path: Some("2.txt".into()),
            },
            UploadQueueItem {
                id: "3".into(),
                source_path: "/tmp/B/standalone.txt".into(),
                target_rel_dir: "".into(),
                target_name: "standalone.txt".into(),
                size: 100,
                transferred_bytes: 100,
                state: TransferState::Uploaded,
                error_message: None,
                created_ts: 1,
                updated_ts: 1,
                parent_folder: None,
                rel_file_path: None,
            },
        ];

        super::retain_incomplete_queue(&mut queue);

        // standalone.txt (id 3) was uploaded and had no folder -> removed
        // A/1.txt (id 1) was uploaded BUT folder A still has A/2.txt in Aguardando -> preserved!
        // A/2.txt (id 2) is Aguardando -> preserved!
        assert_eq!(queue.len(), 2);
        assert!(queue.iter().any(|i| i.id == "1"));
        assert!(queue.iter().any(|i| i.id == "2"));
        assert!(!queue.iter().any(|i| i.id == "3"));
    }

    #[test]
    fn test_subfolder_backup_capped_at_99_while_running() {
        // If an internal file in a subfolder finishes (100%), the subfolder must cap at 99%
        // and NOT jump to 100% Uploaded/Sincronizado while backup is actively running.
        let active_transfers = vec![("Fotos/Viagem/1.jpg".to_string(), 100u8)];
        let remote_names = vec!["Fotos".to_string()];

        let (state, _, pct, note) = super::resolve_backup_item_state(
            "Fotos",
            "Fotos",
            true,
            &active_transfers,
            Some(&remote_names),
            true, // backup is running
            0,
        );
        assert_eq!(state, TransferState::Uploading);
        assert_eq!(pct, 99);
        assert!(note.contains("1 ativa(s)"));

        // When that active transfer ends, folder transitions to Aguardando retaining 99%,
        // NOT 100% Sincronizado
        let (state2, _, pct2, note2) = super::resolve_backup_item_state(
            "Fotos",
            "Fotos",
            true,
            &[],
            Some(&remote_names),
            true, // backup is running
            99, // last_folder_pct
        );
        assert_eq!(state2, TransferState::Aguardando);
        assert_eq!(pct2, 99);
        assert!(note2.contains("fila de envio"));

        // Only when backup is completely finished, folder becomes 100% Sincronizado
        let (state3, _, pct3, note3) = super::resolve_backup_item_state(
            "Fotos",
            "Fotos",
            true,
            &[],
            Some(&remote_names),
            false, // backup finished
            99,
        );
        assert_eq!(state3, TransferState::Uploaded);
        assert_eq!(pct3, 100);
        assert_eq!(note3, "Sincronizado");
    }

    #[test]
    fn test_retain_incomplete_queue_by_target_rel_dir() {
        let mut queue = vec![
            UploadQueueItem {
                id: "f1".into(),
                source_path: "/tmp/1.txt".into(),
                target_rel_dir: "Projetos/Trabalho".into(),
                target_name: "1.txt".into(),
                size: 100,
                transferred_bytes: 100,
                state: TransferState::Uploaded,
                error_message: None,
                created_ts: 1,
                updated_ts: 1,
                parent_folder: None,
                rel_file_path: None,
            },
            UploadQueueItem {
                id: "f2".into(),
                source_path: "/tmp/2.txt".into(),
                target_rel_dir: "Projetos/Trabalho".into(),
                target_name: "2.txt".into(),
                size: 100,
                transferred_bytes: 0,
                state: TransferState::Aguardando,
                error_message: None,
                created_ts: 1,
                updated_ts: 1,
                parent_folder: None,
                rel_file_path: None,
            },
        ];

        super::retain_incomplete_queue(&mut queue);

        // f1 is Uploaded, but f2 in same target_rel_dir is Aguardando -> f1 is preserved!
        assert_eq!(queue.len(), 2);
        assert!(queue.iter().any(|i| i.id == "f1"));
        assert!(queue.iter().any(|i| i.id == "f2"));
    }
}
