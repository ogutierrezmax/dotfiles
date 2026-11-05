// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ChunkStatus {
    OK,
    MISSING,
    DRIFT,
    #[serde(rename = "TARGET_MISSING")]
    TargetMissing,
    ERROR,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChunkItem {
    pub id: string_or_empty::StringWrapper,
    pub chunk_type: String,
    pub target: String,
    pub target_expanded: String,
    pub selector: String,
    pub source: String,
    pub description: String,
    pub status: ChunkStatus,
    pub expected_content: String,
    pub actual_content: String,
    pub current_file_content: String,
    pub projected_file_content: String,
    pub error_message: Option<String>,
}

mod string_or_empty {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    #[derive(Debug, Clone, PartialEq, Eq)]
    pub struct StringWrapper(pub String);

    impl Serialize for StringWrapper {
        fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
        where
            S: Serializer,
        {
            serializer.serialize_str(&self.0)
        }
    }

    impl<'de> Deserialize<'de> for StringWrapper {
        fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
        where
            D: Deserializer<'de>,
        {
            let s = String::deserialize(deserializer)?;
            Ok(StringWrapper(s))
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChunkListResponse {
    pub chunks: Vec<ChunkItem>,
    pub timer_active: boolean_status::TimerStatus,
    pub timer_description: String,
}

mod boolean_status {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct TimerStatus(pub bool);

    impl Serialize for TimerStatus {
        fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
        where
            S: Serializer,
        {
            serializer.serialize_bool(self.0)
        }
    }

    impl<'de> Deserialize<'de> for TimerStatus {
        fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
        where
            D: Deserializer<'de>,
        {
            let b = bool::deserialize(deserializer)?;
            Ok(TimerStatus(b))
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SaveChunkPayload {
    pub original_id: Option<String>,
    pub id: String,
    pub chunk_type: String,
    pub target: String,
    pub selector: String,
    pub content: Option<String>,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChunkConfigFile {
    pub id: Option<String>,
    pub r#type: Option<String>,
    pub target: String,
    pub selector: Option<String>,
    pub description: Option<String>,
    pub payload: Option<serde_json::Value>,
    pub file: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToggleTimerResponse {
    pub active: bool,
}

fn find_repo_root() -> PathBuf {
    if let Ok(env_root) = std::env::var("DOTFILES_REPO_ROOT") {
        let p = PathBuf::from(env_root);
        if p.exists() {
            return p;
        }
    }

    if let Ok(current) = std::env::current_dir() {
        let mut cur = current;
        loop {
            if cur.join("config").join("chunks").exists() || cur.join("scripts").join("chunk-injector.sh").exists() {
                return cur;
            }
            if !cur.pop() {
                break;
            }
        }
    }

    if let Ok(exe_path) = std::env::current_exe() {
        let mut cur = exe_path;
        loop {
            if cur.join("config").join("chunks").exists() || cur.join("scripts").join("chunk-injector.sh").exists() {
                return cur;
            }
            if !cur.pop() {
                break;
            }
        }
    }

    if let Ok(home) = std::env::var("HOME") {
        let default_dotfiles = PathBuf::from(home).join("dotfiles");
        if default_dotfiles.exists() {
            return default_dotfiles;
        }
    }

    PathBuf::from("/home/max/dotfiles")
}

fn expand_path(raw: &str) -> PathBuf {
    if raw.starts_with("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home).join(&raw[2..]);
        }
    } else if raw.starts_with("$HOME/") {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home).join(&raw[6..]);
        }
    }
    PathBuf::from(raw)
}

fn load_source_content(repo_root: &Path, src_spec: &str) -> Result<String, String> {
    if let Some(stripped) = src_spec.strip_prefix("json:") {
        return Ok(stripped.to_string());
    }
    if let Some(stripped) = src_spec.strip_prefix("text:") {
        return Ok(stripped.to_string());
    }

    let resolved = if src_spec.starts_with('/') {
        PathBuf::from(src_spec)
    } else {
        repo_root.join(src_spec)
    };

    fs::read_to_string(&resolved)
        .map_err(|e| format!("Não foi possível ler {}: {}", resolved.display(), e))
}

fn compute_projected_file(
    chunk_type: &str,
    id: &str,
    selector: &str,
    expected_content: &str,
    target_content: &str,
) -> (String, String) {
    match chunk_type {
        "json-key" => {
            let expected_json_val: serde_json::Value = match serde_json::from_str(expected_content) {
                Ok(v) => v,
                Err(_) => serde_json::Value::String(expected_content.to_string()),
            };

            let mut target_val: serde_json::Value = match serde_json::from_str(target_content) {
                Ok(v) => v,
                Err(_) => serde_json::json!({}),
            };

            let current_pretty = if let Ok(val) = serde_json::from_str::<serde_json::Value>(target_content) {
                serde_json::to_string_pretty(&val).unwrap_or_else(|_| target_content.to_string())
            } else {
                target_content.to_string()
            };

            if selector == "." || selector == "-" || selector.is_empty() {
                if let Some(target_map) = target_val.as_object_mut() {
                    if let Some(expected_map) = expected_json_val.as_object() {
                        for (k, v) in expected_map {
                            target_map.insert(k.clone(), v.clone());
                        }
                    }
                }
            } else {
                let key = selector.trim_start_matches('.');
                if let Some(map) = target_val.as_object_mut() {
                    map.insert(key.to_string(), expected_json_val);
                }
            }

            let projected_pretty = serde_json::to_string_pretty(&target_val).unwrap_or_else(|_| target_content.to_string());
            (current_pretty, projected_pretty)
        }
        "block" => {
            let prefix = if selector.is_empty() || selector == "-" { "#" } else { selector };
            let begin_mark = format!("{} >>> chunk-injector:{} >>>", prefix, id);
            let end_mark = format!("{} <<< chunk-injector:{} <<<", prefix, id);

            let has_begin = target_content.lines().any(|l| l.trim() == begin_mark.trim());
            let has_end = target_content.lines().any(|l| l.trim() == end_mark.trim());

            let current = target_content.to_string();
            let projected = if has_begin && has_end {
                let mut lines = Vec::new();
                let mut in_block = false;
                for line in target_content.lines() {
                    if line.trim() == begin_mark.trim() {
                        lines.push(line.to_string());
                        lines.push(expected_content.trim_end().to_string());
                        in_block = true;
                        continue;
                    }
                    if line.trim() == end_mark.trim() {
                        lines.push(line.to_string());
                        in_block = false;
                        continue;
                    }
                    if !in_block {
                        lines.push(line.to_string());
                    }
                }
                lines.join("\n")
            } else {
                let mut s = target_content.to_string();
                if !s.is_empty() && !s.ends_with('\n') {
                    s.push('\n');
                }
                format!("{}{}\n{}\n{}\n", s, begin_mark, expected_content.trim_end(), end_mark)
            };
            (current, projected)
        }
        "line" => {
            let first_line = expected_content.lines().next().unwrap_or("").trim();
            let current = target_content.to_string();
            let found = target_content.lines().any(|l| l.trim() == first_line);
            let projected = if found {
                current.clone()
            } else {
                let mut s = target_content.to_string();
                if !s.is_empty() && !s.ends_with('\n') {
                    s.push('\n');
                }
                s.push_str(first_line);
                s.push('\n');
                s
            };
            (current, projected)
        }
        _ => (target_content.to_string(), target_content.to_string()),
    }
}

fn inspect_chunk_file(repo_root: &Path, file_path: &Path) -> Option<ChunkItem> {
    let file_content = fs::read_to_string(file_path).ok()?;
    let parsed: ChunkConfigFile = serde_json::from_str(&file_content).ok()?;

    let id = parsed.id.unwrap_or_else(|| {
        file_path.file_stem().and_then(|s| s.to_str()).unwrap_or("chunk").to_string()
    });
    let chunk_type = parsed.r#type.unwrap_or_else(|| "block".to_string());
    let target_raw = parsed.target;
    let selector = parsed.selector.unwrap_or_else(|| {
        if chunk_type == "json-key" { ".".to_string() } else { "#".to_string() }
    });
    let description = parsed.description.unwrap_or_else(|| id.clone());
    let src_spec = file_path.to_string_lossy().to_string();

    let target_expanded = expand_path(&target_raw);
    let target_str = target_expanded.to_string_lossy().to_string();

    let expected_content = if let Some(payload_val) = parsed.payload {
        if chunk_type == "json-key" {
            serde_json::to_string_pretty(&payload_val).unwrap_or_else(|_| payload_val.to_string())
        } else if let Some(s) = payload_val.as_str() {
            s.to_string()
        } else {
            payload_val.to_string()
        }
    } else if let Some(file_rel) = parsed.file {
        load_source_content(repo_root, &file_rel).unwrap_or_default()
    } else {
        String::new()
    };

    if !target_expanded.exists() {
        let (current_file_content, projected_file_content) =
            compute_projected_file(&chunk_type, &id, &selector, &expected_content, "");
        return Some(ChunkItem {
            id: string_or_empty::StringWrapper(id),
            chunk_type,
            target: target_raw,
            target_expanded: target_str,
            selector,
            source: src_spec,
            description,
            status: ChunkStatus::TargetMissing,
            expected_content,
            actual_content: String::new(),
            current_file_content,
            projected_file_content,
            error_message: Some("Arquivo-alvo não existe no disco".into()),
        });
    }

    let target_file_content = match fs::read_to_string(&target_expanded) {
        Ok(c) => c,
        Err(e) => {
            return Some(ChunkItem {
                id: string_or_empty::StringWrapper(id),
                chunk_type,
                target: target_raw,
                target_expanded: target_str,
                selector,
                source: src_spec,
                description,
                status: ChunkStatus::ERROR,
                expected_content,
                actual_content: String::new(),
                current_file_content: String::new(),
                projected_file_content: String::new(),
                error_message: Some(format!("Erro ao ler arquivo-alvo: {}", e)),
            });
        }
    };

    let (current_file_content, projected_file_content) = compute_projected_file(
        &chunk_type,
        &id,
        &selector,
        &expected_content,
        &target_file_content,
    );

    match chunk_type.as_str() {
        "json-key" => {
            let expected_json: serde_json::Value = match serde_json::from_str(&expected_content) {
                Ok(v) => v,
                Err(e) => {
                    return Some(ChunkItem {
                        id: string_or_empty::StringWrapper(id),
                        chunk_type,
                        target: target_raw,
                        target_expanded: target_str,
                        selector,
                        source: src_spec,
                        description,
                        status: ChunkStatus::ERROR,
                        expected_content,
                        actual_content: String::new(),
                        current_file_content,
                        projected_file_content,
                        error_message: Some(format!("JSON esperado inválido: {}", e)),
                    });
                }
            };

            let target_json: serde_json::Value = match serde_json::from_str(&target_file_content) {
                Ok(v) => v,
                Err(e) => {
                    return Some(ChunkItem {
                        id: string_or_empty::StringWrapper(id),
                        chunk_type,
                        target: target_raw,
                        target_expanded: target_str,
                        selector,
                        source: src_spec,
                        description,
                        status: ChunkStatus::DRIFT,
                        expected_content: serde_json::to_string_pretty(&expected_json).unwrap_or(expected_content),
                        actual_content: target_file_content,
                        current_file_content,
                        projected_file_content,
                        error_message: Some(format!("JSON do arquivo-alvo não parseável: {}", e)),
                    });
                }
            };

            let expected_pretty = serde_json::to_string_pretty(&expected_json).unwrap_or(expected_content);

            if selector == "." || selector == "-" || selector.is_empty() {
                if let Some(expected_map) = expected_json.as_object() {
                    let target_map_opt = target_json.as_object();
                    let mut all_match = true;
                    let mut any_missing = false;
                    let mut actual_map = serde_json::Map::new();

                    for (k, v) in expected_map {
                        match target_map_opt.and_then(|m| m.get(k)) {
                            None => {
                                any_missing = true;
                                all_match = false;
                            }
                            Some(actual_v) => {
                                actual_map.insert(k.clone(), actual_v.clone());
                                if actual_v != v {
                                    all_match = false;
                                }
                            }
                        }
                    }

                    let status = if all_match {
                        ChunkStatus::OK
                    } else if any_missing {
                        ChunkStatus::MISSING
                    } else {
                        ChunkStatus::DRIFT
                    };

                    let actual_pretty = if actual_map.is_empty() {
                        "(nenhuma das chaves presente no arquivo)".to_string()
                    } else {
                        serde_json::to_string_pretty(&serde_json::Value::Object(actual_map)).unwrap_or_else(|_| "{}".into())
                    };

                    Some(ChunkItem {
                        id: string_or_empty::StringWrapper(id),
                        chunk_type,
                        target: target_raw,
                        target_expanded: target_str,
                        selector,
                        source: src_spec,
                        description,
                        status,
                        expected_content: expected_pretty,
                        actual_content: actual_pretty,
                        current_file_content,
                        projected_file_content,
                        error_message: None,
                    })
                } else {
                    Some(ChunkItem {
                        id: string_or_empty::StringWrapper(id),
                        chunk_type,
                        target: target_raw,
                        target_expanded: target_str,
                        selector,
                        source: src_spec,
                        description,
                        status: ChunkStatus::ERROR,
                        expected_content: expected_pretty,
                        actual_content: String::new(),
                        current_file_content,
                        projected_file_content,
                        error_message: Some("O trecho JSON para seletor '.' deve ser um objeto JSON".into()),
                    })
                }
            } else {
                let key = selector.trim_start_matches('.');
                let actual_val = target_json.get(key);

                match actual_val {
                    None => Some(ChunkItem {
                        id: string_or_empty::StringWrapper(id),
                        chunk_type,
                        target: target_raw,
                        target_expanded: target_str,
                        selector,
                        source: src_spec,
                        description,
                        status: ChunkStatus::MISSING,
                        expected_content: expected_pretty,
                        actual_content: "(chave ausente)".into(),
                        current_file_content,
                        projected_file_content,
                        error_message: None,
                    }),
                    Some(val) => {
                        let actual_pretty = serde_json::to_string_pretty(val).unwrap_or_else(|_| val.to_string());
                        let status = if val == &expected_json {
                            ChunkStatus::OK
                        } else {
                            ChunkStatus::DRIFT
                        };
                        Some(ChunkItem {
                            id: string_or_empty::StringWrapper(id),
                            chunk_type,
                            target: target_raw,
                            target_expanded: target_str,
                            selector,
                            source: src_spec,
                            description,
                            status,
                            expected_content: expected_pretty,
                            actual_content: actual_pretty,
                            current_file_content,
                            projected_file_content,
                            error_message: None,
                        })
                    }
                }
            }
        }
        "block" => {
            let prefix = if selector.is_empty() || selector == "-" {
                "#"
            } else {
                selector.as_str()
            };
            let begin_mark = format!("{} >>> chunk-injector:{} >>>", prefix, id);
            let end_mark = format!("{} <<< chunk-injector:{} <<<", prefix, id);

            let has_begin = target_file_content.lines().any(|l| l.trim() == begin_mark.trim());
            let has_end = target_file_content.lines().any(|l| l.trim() == end_mark.trim());

            if !has_begin || !has_end {
                return Some(ChunkItem {
                    id: string_or_empty::StringWrapper(id),
                    chunk_type,
                    target: target_raw,
                    target_expanded: target_str,
                    selector,
                    source: src_spec,
                    description,
                    status: ChunkStatus::MISSING,
                    expected_content,
                    actual_content: "(marcadores de bloco ausentes)".into(),
                    current_file_content,
                    projected_file_content,
                    error_message: None,
                });
            }

            let mut in_block = false;
            let mut extracted = Vec::new();
            for line in target_file_content.lines() {
                if line.trim() == begin_mark.trim() {
                    in_block = true;
                    continue;
                }
                if line.trim() == end_mark.trim() {
                    break;
                }
                if in_block {
                    extracted.push(line);
                }
            }

            let actual_block = extracted.join("\n");
            let norm_expected = expected_content.trim();
            let norm_actual = actual_block.trim();

            let status = if norm_actual == norm_expected {
                ChunkStatus::OK
            } else {
                ChunkStatus::DRIFT
            };

            Some(ChunkItem {
                id: string_or_empty::StringWrapper(id),
                chunk_type,
                target: target_raw,
                target_expanded: target_str,
                selector,
                source: src_spec,
                description,
                status,
                expected_content,
                actual_content: actual_block,
                current_file_content,
                projected_file_content,
                error_message: None,
            })
        }
        "line" => {
            let first_line = expected_content.lines().next().unwrap_or("").trim();
            let found = target_file_content.lines().any(|l| l.trim() == first_line);

            let status = if found {
                ChunkStatus::OK
            } else {
                ChunkStatus::MISSING
            };

            Some(ChunkItem {
                id: string_or_empty::StringWrapper(id),
                chunk_type,
                target: target_raw,
                target_expanded: target_str,
                selector,
                source: src_spec,
                description,
                status,
                expected_content: first_line.to_string(),
                actual_content: if found { first_line.to_string() } else { "(linha não encontrada)".into() },
                current_file_content,
                projected_file_content,
                error_message: None,
            })
        }
        _ => Some(ChunkItem {
            id: string_or_empty::StringWrapper(id),
            chunk_type: chunk_type.clone(),
            target: target_raw,
            target_expanded: target_str,
            selector,
            source: src_spec,
            description,
            status: ChunkStatus::ERROR,
            expected_content,
            actual_content: String::new(),
            current_file_content,
            projected_file_content,
            error_message: Some(format!("Tipo de chunk desconhecido: {}", chunk_type)),
        }),
    }
}

fn is_timer_active() -> bool {
    let output = Command::new("systemctl")
        .args(["--user", "is-active", "chunk-injector-monitor.timer"])
        .output();

    match output {
        Ok(out) => {
            let status = String::from_utf8_lossy(&out.stdout).trim().to_string();
            status == "active"
        }
        Err(_) => false,
    }
}

#[tauri::command]
fn list_chunks_status() -> Result<ChunkListResponse, String> {
    let repo_root = find_repo_root();
    let chunks_dir = repo_root.join("config").join("chunks");

    let mut chunks = Vec::new();
    if chunks_dir.exists() {
        if let Ok(entries) = fs::read_dir(&chunks_dir) {
            let mut paths: Vec<PathBuf> = entries
                .filter_map(|e| e.ok())
                .map(|e| e.path())
                .filter(|p| p.extension().and_then(|s| s.to_str()) == Some("json"))
                .collect();
            paths.sort();
            for path in paths {
                if let Some(item) = inspect_chunk_file(&repo_root, &path) {
                    chunks.push(item);
                }
            }
        }
    }

    let timer_active = is_timer_active();
    let timer_description = if timer_active {
        "Monitoramento periódico ativo (a cada 5 min)".to_string()
    } else {
        "Monitoramento periódico inativo".to_string()
    };

    Ok(ChunkListResponse {
        chunks,
        timer_active: boolean_status::TimerStatus(timer_active),
        timer_description,
    })
}

#[tauri::command]
fn inject_chunk(id: String) -> Result<String, String> {
    let repo_root = find_repo_root();
    let script = repo_root.join("scripts").join("chunk-injector.sh");

    if !script.exists() {
        return Err(format!("Script {} não encontrado", script.display()));
    }

    let output = Command::new("bash")
        .arg(&script)
        .arg("inject")
        .arg("--only")
        .arg(&id)
        .output()
        .map_err(|e| format!("Falha ao executar script: {}", e))?;

    if !output.status.success() {
        let err_msg = String::from_utf8_lossy(&output.stderr);
        let out_msg = String::from_utf8_lossy(&output.stdout);
        return Err(format!("Erro ao injetar {}: {}\n{}", id, err_msg, out_msg));
    }

    Ok(format!("Chunk {} injetado com sucesso", id))
}

#[tauri::command]
fn inject_all_chunks() -> Result<String, String> {
    let repo_root = find_repo_root();
    let script = repo_root.join("scripts").join("chunk-injector.sh");

    if !script.exists() {
        return Err(format!("Script {} não encontrado", script.display()));
    }

    let output = Command::new("bash")
        .arg(&script)
        .arg("inject")
        .output()
        .map_err(|e| format!("Falha ao executar script: {}", e))?;

    if !output.status.success() {
        let err_msg = String::from_utf8_lossy(&output.stderr);
        let out_msg = String::from_utf8_lossy(&output.stdout);
        return Err(format!("Erro ao injetar chunks: {}\n{}", err_msg, out_msg));
    }

    Ok("Todos os chunks foram processados com sucesso".to_string())
}

#[tauri::command]
fn undo_chunk(id: String) -> Result<String, String> {
    let repo_root = find_repo_root();
    let script = repo_root.join("scripts").join("chunk-injector.sh");

    if !script.exists() {
        return Err(format!("Script {} não encontrado", script.display()));
    }

    let output = Command::new("bash")
        .arg(&script)
        .arg("revert")
        .arg("--only")
        .arg(&id)
        .output()
        .map_err(|e| format!("Falha ao executar script: {}", e))?;

    if !output.status.success() {
        let err_msg = String::from_utf8_lossy(&output.stderr);
        let out_msg = String::from_utf8_lossy(&output.stdout);
        return Err(format!("Erro ao desfazer {}: {}\n{}", id, err_msg, out_msg));
    }

    Ok(format!("Injeção do chunk {} desfeita com sucesso", id))
}

#[tauri::command]
fn save_chunk_entry(payload: SaveChunkPayload) -> Result<String, String> {
    let repo_root = find_repo_root();
    let chunks_dir = repo_root.join("config").join("chunks");
    fs::create_dir_all(&chunks_dir)
        .map_err(|e| format!("Falha ao criar diretório {}: {}", chunks_dir.display(), e))?;

    if let Some(orig_id) = &payload.original_id {
        if orig_id != &payload.id {
            let old_file = chunks_dir.join(format!("{}.json", orig_id));
            if old_file.exists() {
                let _ = fs::remove_file(old_file);
            }
        }
    }

    let chunk_file = chunks_dir.join(format!("{}.json", payload.id));
    let content_str = payload.content.unwrap_or_default();

    let payload_val = if payload.chunk_type == "json-key" {
        serde_json::from_str(&content_str).unwrap_or_else(|_| serde_json::Value::String(content_str))
    } else {
        serde_json::Value::String(content_str)
    };

    let selector = if payload.selector.trim().is_empty() {
        if payload.chunk_type == "json-key" { ".".to_string() } else { "#".to_string() }
    } else {
        payload.selector.trim().to_string()
    };

    let chunk_def = serde_json::json!({
        "id": payload.id,
        "type": payload.chunk_type,
        "target": payload.target,
        "selector": selector,
        "description": payload.description,
        "payload": payload_val
    });

    let pretty = serde_json::to_string_pretty(&chunk_def)
        .map_err(|e| format!("Erro ao serializar chunk JSON: {}", e))?;

    fs::write(&chunk_file, pretty + "\n")
        .map_err(|e| format!("Erro ao salvar {}: {}", chunk_file.display(), e))?;

    Ok(format!("Chunk {} salvo com sucesso", payload.id))
}

#[tauri::command]
fn delete_chunk_entry(id: String) -> Result<String, String> {
    let repo_root = find_repo_root();
    let chunk_file = repo_root.join("config").join("chunks").join(format!("{}.json", id));

    if chunk_file.exists() {
        fs::remove_file(&chunk_file)
            .map_err(|e| format!("Erro ao remover {}: {}", chunk_file.display(), e))?;
    } else {
        return Err(format!("Chunk {} não encontrado em config/chunks/", id));
    }

    Ok(format!("Chunk {} removido", id))
}

#[tauri::command]
fn toggle_systemd_timer() -> Result<ToggleTimerResponse, String> {
    let current_active = is_timer_active();
    let target_action = if current_active { "stop" } else { "start" };

    let output = Command::new("systemctl")
        .args(["--user", target_action, "chunk-injector-monitor.timer"])
        .output()
        .map_err(|e| format!("Falha ao alterar timer: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "Erro ao executar systemctl {}: {}",
            target_action,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(ToggleTimerResponse {
        active: !current_active,
    })
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            list_chunks_status,
            inject_chunk,
            inject_all_chunks,
            undo_chunk,
            save_chunk_entry,
            delete_chunk_entry,
            toggle_systemd_timer
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_expand_path() {
        let p = expand_path("~/test.txt");
        assert!(p.to_string_lossy().contains("test.txt"));
        assert!(!p.to_string_lossy().starts_with("~/"));
    }

    #[test]
    fn test_load_source_inline() {
        let root = PathBuf::from("/tmp");
        let json_res = load_source_content(&root, "json:{\"a\":1}").unwrap();
        assert_eq!(json_res, "{\"a\":1}");

        let text_res = load_source_content(&root, "text:export FOO=1").unwrap();
        assert_eq!(text_res, "export FOO=1");
    }

    #[test]
    fn test_list_chunks_status_real() {
        let res = list_chunks_status();
        println!("LIST CHUNKS RESULT: {:?}", res);
        assert!(res.is_ok());
        let data = res.unwrap();
        println!("CHUNKS COUNT: {}", data.chunks.len());
        for c in &data.chunks {
            println!("CHUNK: id={:?}, status={:?}, target={}", c.id, c.status, c.target);
        }
    }
}

