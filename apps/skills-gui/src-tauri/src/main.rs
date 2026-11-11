// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

// ---------------------------------------------------------------------------
// Modelo do catálogo (apps/skills-gui/catalog/skills-catalog.json)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Category {
    id: String,
    label: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    order: Option<i64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    color: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct CatalogSkill {
    #[serde(default)]
    category: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    tools: Option<Vec<String>>,
    #[serde(default)]
    favorite: bool,
    #[serde(default)]
    notes: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    updated_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Catalog {
    version: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    updated_at: Option<String>,
    #[serde(default)]
    categories: Vec<Category>,
    #[serde(default)]
    skills: BTreeMap<String, CatalogSkill>,
}

// ---------------------------------------------------------------------------
// Modelo do arquivo (apps/skills-gui/archive/archive-catalog.json)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct ArchiveSkillEntry {
    #[serde(default)]
    category: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    tools: Option<Vec<String>>,
    #[serde(default)]
    favorite: bool,
    #[serde(default)]
    notes: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    archived_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ArchiveCatalog {
    version: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    updated_at: Option<String>,
    #[serde(default)]
    skills: BTreeMap<String, ArchiveSkillEntry>,
}

// ---------------------------------------------------------------------------
// Modelo exposto à interface
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct SkillItem {
    /// Nome do diretório em ~/.agents/skills (id estável).
    name: String,
    /// Campo `name:` do frontmatter, quando presente.
    display_name: String,
    description: String,
    category: Option<String>,
    tags: Vec<String>,
    tools: Option<Vec<String>>,
    favorite: bool,
    notes: String,
    path: String,
    file_count: usize,
    size_bytes: u64,
    modified_at: String,
    name_mismatch: bool,
    has_frontmatter: bool,
    archived: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    archived_at: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct SkillDetail {
    #[serde(flatten)]
    item: SkillItem,
    content: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct AppData {
    repo_root: String,
    skills_dir: String,
    archive_dir: String,
    catalog_path: String,
    skills: Vec<SkillItem>,
    archived_skills: Vec<SkillItem>,
    categories: Vec<Category>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct HealthReport {
    skills_flat: usize,
    nested: Vec<String>,
    at_names: Vec<String>,
    catalog_total: usize,
    missing_in_catalog: Vec<String>,
    orphan_in_catalog: Vec<String>,
    name_mismatches: Vec<NameMismatch>,
    broken_links: Vec<String>,
    ok: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct NameMismatch {
    dir: String,
    name: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ScriptResult {
    ok: bool,
    code: i32,
    output: String,
}

// ---------------------------------------------------------------------------
// Localização do repositório e caminhos
// ---------------------------------------------------------------------------

/// Um repositório de dotfiles válido precisa do acervo de skills em
/// `data/.agents/skills` — sem esse marcador, `apps/skills-gui` (que também tem
/// `catalog/`) seria confundido com a raiz ao subir a partir de `target/release`.
fn looks_like_repo(p: &Path) -> bool {
    if !p.join("data").join(".agents").join("skills").is_dir() {
        return false;
    }
    p.join("apps").join("skills-gui").join("catalog").exists()
        || (p.join("config").join("agent-skills-bridge.list").exists()
            && p.join("scripts").join("install-agent-skills-bridge.sh").exists())
}

fn find_repo_root() -> PathBuf {
    if let Ok(env_root) = std::env::var("DOTFILES_REPO_ROOT") {
        let p = PathBuf::from(env_root);
        if looks_like_repo(&p) {
            return p;
        }
    }

    if let Ok(current) = std::env::current_dir() {
        let mut cur = current;
        loop {
            if looks_like_repo(&cur) {
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
            if looks_like_repo(&cur) {
                return cur;
            }
            if !cur.pop() {
                break;
            }
        }
    }

    // Último recurso: instalação padrão dos dotfiles em ~/dotfiles.
    if let Ok(home) = std::env::var("HOME") {
        let candidate = PathBuf::from(home).join("dotfiles");
        if looks_like_repo(&candidate) {
            return candidate;
        }
    }

    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(|p| p.parent())
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."))
}

fn skills_dir(root: &Path) -> PathBuf {
    root.join("data").join(".agents").join("skills")
}

fn catalog_path(root: &Path) -> PathBuf {
    root.join("apps")
        .join("skills-gui")
        .join("catalog")
        .join("skills-catalog.json")
}

fn archive_dir(root: &Path) -> PathBuf {
    root.join("apps").join("skills-gui").join("archive")
}

fn archive_catalog_path(root: &Path) -> PathBuf {
    archive_dir(root).join("archive-catalog.json")
}

// ---------------------------------------------------------------------------
// Utilitários
// ---------------------------------------------------------------------------

fn now_iso() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;
    iso_from_unix(secs)
}

fn iso_from_unix(secs: i64) -> String {
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    let (y, m, d) = civil_from_days(days);
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        y,
        m,
        d,
        rem / 3600,
        (rem % 3600) / 60,
        rem % 60
    )
}

fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (y + i64::from(m <= 2), m, d)
}

fn modified_iso(path: &Path) -> String {
    fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| iso_from_unix(d.as_secs() as i64))
        .unwrap_or_default()
}

fn unquote(value: &str) -> String {
    let v = value.trim();
    if v.len() >= 2 {
        let bytes = v.as_bytes();
        let first = bytes[0];
        let last = bytes[v.len() - 1];
        if (first == b'"' && last == b'"') || (first == b'\'' && last == b'\'') {
            return v[1..v.len() - 1].to_string();
        }
    }
    v.to_string()
}

/// Parser mínimo de frontmatter YAML: extrai `name` e `description`.
/// Suporta valores inline (com ou sem aspas) e blocos `>` / `|`.
fn parse_frontmatter(content: &str) -> (Option<String>, Option<String>, bool) {
    let mut lines = content.lines();
    if lines.next().map(str::trim) != Some("---") {
        return (None, None, false);
    }

    let mut name: Option<String> = None;
    let mut description: Option<String> = None;
    let mut current: Option<String> = None;
    let mut block: Vec<String> = Vec::new();

    let flush = |current: &mut Option<String>, block: &mut Vec<String>, name: &mut Option<String>, description: &mut Option<String>| {
        if let Some(key) = current.take() {
            let joined = block
                .iter()
                .map(|l| l.trim())
                .filter(|l| !l.is_empty())
                .collect::<Vec<_>>()
                .join(" ");
            block.clear();
            if key == "name" && name.is_none() {
                *name = Some(joined);
            } else if key == "description" && description.is_none() {
                *description = Some(joined);
            }
        }
    };

    let mut closed = false;
    for line in lines {
        if line.trim() == "---" {
            closed = true;
            break;
        }

        if let Some(rest) = line.strip_prefix("name:") {
            flush(&mut current, &mut block, &mut name, &mut description);
            name = Some(unquote(rest));
            continue;
        }
        if let Some(rest) = line.strip_prefix("description:") {
            flush(&mut current, &mut block, &mut name, &mut description);
            let rest = rest.trim();
            if rest.starts_with('>') || rest.starts_with('|') {
                current = Some("description".to_string());
            } else {
                description = Some(unquote(rest));
            }
            continue;
        }

        if current.is_some() {
            if line.starts_with(' ') || line.starts_with('\t') || line.trim().is_empty() {
                block.push(line.to_string());
            } else {
                flush(&mut current, &mut block, &mut name, &mut description);
            }
        }
    }
    flush(&mut current, &mut block, &mut name, &mut description);

    (name, description, closed)
}

fn dir_stats(path: &Path) -> (usize, u64) {
    let mut files = 0usize;
    let mut bytes = 0u64;
    let mut stack = vec![path.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = fs::read_dir(&dir) else { continue };
        for entry in entries.flatten() {
            let p = entry.path();
            let Ok(meta) = entry.metadata() else { continue };
            if meta.is_dir() {
                stack.push(p);
            } else if meta.is_file() {
                files += 1;
                bytes += meta.len();
            }
        }
    }
    (files, bytes)
}

fn read_catalog(path: &Path) -> Catalog {
    match fs::read_to_string(path) {
        Ok(text) => serde_json::from_str::<Catalog>(&text).unwrap_or(Catalog {
            version: 1,
            updated_at: None,
            categories: Vec::new(),
            skills: BTreeMap::new(),
        }),
        Err(_) => Catalog {
            version: 1,
            updated_at: None,
            categories: Vec::new(),
            skills: BTreeMap::new(),
        },
    }
}

fn write_catalog(path: &Path, catalog: &Catalog) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("criar diretório do catálogo: {e}"))?;
    }
    let json = serde_json::to_string_pretty(catalog)
        .map_err(|e| format!("serializar catálogo: {e}"))?;
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, format!("{json}\n")).map_err(|e| format!("gravar catálogo: {e}"))?;
    fs::rename(&tmp, path).map_err(|e| format!("publicar catálogo: {e}"))?;
    Ok(())
}

fn read_archive_catalog(path: &Path) -> ArchiveCatalog {
    match fs::read_to_string(path) {
        Ok(text) => serde_json::from_str::<ArchiveCatalog>(&text).unwrap_or(ArchiveCatalog {
            version: 1,
            updated_at: None,
            skills: BTreeMap::new(),
        }),
        Err(_) => ArchiveCatalog {
            version: 1,
            updated_at: None,
            skills: BTreeMap::new(),
        },
    }
}

fn write_archive_catalog(path: &Path, catalog: &ArchiveCatalog) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("criar diretório do arquivo: {e}"))?;
    }
    let json = serde_json::to_string_pretty(catalog)
        .map_err(|e| format!("serializar catálogo do arquivo: {e}"))?;
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, format!("{json}\n")).map_err(|e| format!("gravar catálogo do arquivo: {e}"))?;
    fs::rename(&tmp, path).map_err(|e| format!("publicar catálogo do arquivo: {e}"))?;
    Ok(())
}

fn load_skills(root: &Path) -> Result<AppData, String> {
    let center = skills_dir(root);
    let catalog_file = catalog_path(root);
    let catalog = read_catalog(&catalog_file);

    let mut items: Vec<SkillItem> = Vec::new();
    let entries = fs::read_dir(&center).map_err(|e| {
        format!(
            "ler acervo {}: {e} (repo detectado: {})",
            center.display(),
            root.display()
        )
    })?;

    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let skill_md = path.join("SKILL.md");
        if !skill_md.is_file() {
            continue;
        }
        let dir_name = entry.file_name().to_string_lossy().to_string();
        let content = fs::read_to_string(&skill_md).unwrap_or_default();
        let (fm_name, fm_desc, has_frontmatter) = parse_frontmatter(&content);
        let (file_count, size_bytes) = dir_stats(&path);
        let meta = catalog.skills.get(&dir_name).cloned().unwrap_or_default();

        let display_name = fm_name.clone().unwrap_or_else(|| dir_name.clone());
        let name_mismatch = fm_name
            .as_deref()
            .map(|n| n != dir_name)
            .unwrap_or(false);

        items.push(SkillItem {
            name: dir_name.clone(),
            display_name,
            description: fm_desc.unwrap_or_default(),
            category: meta.category.clone(),
            tags: meta.tags.clone(),
            tools: meta.tools.clone(),
            favorite: meta.favorite,
            notes: meta.notes.clone(),
            path: path.to_string_lossy().to_string(),
            file_count,
            size_bytes,
            modified_at: modified_iso(&skill_md),
            name_mismatch,
            has_frontmatter,
            archived: false,
            archived_at: None,
        });
    }

    items.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    // Escanear pasta do arquivo (apps/skills-gui/archive)
    let arch_dir = archive_dir(root);
    let arch_cat_file = archive_catalog_path(root);
    let arch_cat = read_archive_catalog(&arch_cat_file);
    let mut archived_items: Vec<SkillItem> = Vec::new();

    if arch_dir.is_dir() {
        if let Ok(arch_entries) = fs::read_dir(&arch_dir) {
            for entry in arch_entries.flatten() {
                let path = entry.path();
                if !path.is_dir() {
                    continue;
                }
                let skill_md = path.join("SKILL.md");
                if !skill_md.is_file() {
                    continue;
                }
                let dir_name = entry.file_name().to_string_lossy().to_string();
                let content = fs::read_to_string(&skill_md).unwrap_or_default();
                let (fm_name, fm_desc, has_frontmatter) = parse_frontmatter(&content);
                let (file_count, size_bytes) = dir_stats(&path);
                let meta = arch_cat.skills.get(&dir_name).cloned().unwrap_or_default();

                let display_name = fm_name.clone().unwrap_or_else(|| dir_name.clone());
                let name_mismatch = fm_name
                    .as_deref()
                    .map(|n| n != dir_name)
                    .unwrap_or(false);

                archived_items.push(SkillItem {
                    name: dir_name.clone(),
                    display_name,
                    description: fm_desc.unwrap_or_default(),
                    category: meta.category.clone(),
                    tags: meta.tags.clone(),
                    tools: meta.tools.clone(),
                    favorite: meta.favorite,
                    notes: meta.notes.clone(),
                    path: path.to_string_lossy().to_string(),
                    file_count,
                    size_bytes,
                    modified_at: modified_iso(&skill_md),
                    name_mismatch,
                    has_frontmatter,
                    archived: true,
                    archived_at: meta.archived_at,
                });
            }
        }
    }

    archived_items.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    let mut categories = catalog.categories.clone();
    categories.sort_by_key(|c| (c.order.unwrap_or(999), c.id.clone()));

    Ok(AppData {
        repo_root: root.to_string_lossy().to_string(),
        skills_dir: center.to_string_lossy().to_string(),
        archive_dir: arch_dir.to_string_lossy().to_string(),
        catalog_path: catalog_file.to_string_lossy().to_string(),
        skills: items,
        archived_skills: archived_items,
        categories,
    })
}

fn is_valid_skill_slug(name: &str) -> bool {
    if name.is_empty()
        || name.contains("..")
        || name.contains('/')
        || name.contains('\\')
        || name.ends_with('.')
        || name.ends_with(' ')
    {
        return false;
    }
    let mut chars = name.chars();
    let first = match chars.next() {
        Some(c) => c,
        None => return false,
    };
    if !first.is_ascii_lowercase() && !first.is_ascii_digit() && first != '_' {
        return false;
    }
    chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '.' || c == '_' || c == '-')
}

fn valid_skill_dir(root: &Path, name: &str) -> Result<PathBuf, String> {
    if !is_valid_skill_slug(name) {
        return Err(format!("nome de skill inválido: {name}"));
    }
    let center = skills_dir(root);
    let path = center.join(name);
    if !path.join("SKILL.md").is_file() {
        return Err(format!("skill não encontrada: {name}"));
    }

    // Validação estrita de caminho canônico para impedir path traversal
    let canonical_path = path
        .canonicalize()
        .map_err(|e| format!("caminho inválido: {e}"))?;
    let canonical_center = center
        .canonicalize()
        .map_err(|e| format!("acervo inválido: {e}"))?;

    if !canonical_path.starts_with(&canonical_center) || canonical_path == canonical_center {
        return Err("caminho fora do acervo de skills".to_string());
    }

    Ok(path)
}

fn valid_archived_skill_dir(root: &Path, name: &str) -> Result<PathBuf, String> {
    if !is_valid_skill_slug(name) {
        return Err(format!("nome de skill inválido: {name}"));
    }
    let arch_dir = archive_dir(root);
    let path = arch_dir.join(name);
    if !path.join("SKILL.md").is_file() {
        return Err(format!("skill arquivada não encontrada: {name}"));
    }

    // Validação estrita de caminho canônico para impedir path traversal
    let canonical_path = path
        .canonicalize()
        .map_err(|e| format!("caminho inválido: {e}"))?;
    let canonical_arch = arch_dir
        .canonicalize()
        .map_err(|e| format!("pasta do arquivo inválida: {e}"))?;

    if !canonical_path.starts_with(&canonical_arch) || canonical_path == canonical_arch {
        return Err("caminho fora da pasta de arquivo de skills".to_string());
    }

    Ok(path)
}

// ---------------------------------------------------------------------------
// Comandos Tauri
// ---------------------------------------------------------------------------

#[tauri::command]
fn list_skills() -> Result<AppData, String> {
    let root = find_repo_root();
    load_skills(&root)
}

#[tauri::command]
fn get_skill(name: String) -> Result<SkillDetail, String> {
    let root = find_repo_root();
    let data = load_skills(&root)?;

    if let Ok(dir) = valid_skill_dir(&root, &name) {
        let content = fs::read_to_string(dir.join("SKILL.md"))
            .map_err(|e| format!("ler SKILL.md: {e}"))?;
        let item = data
            .skills
            .into_iter()
            .find(|s| s.name == name)
            .ok_or_else(|| format!("skill não encontrada no acervo: {name}"))?;
        return Ok(SkillDetail { item, content });
    }

    if let Ok(dir) = valid_archived_skill_dir(&root, &name) {
        let content = fs::read_to_string(dir.join("SKILL.md"))
            .map_err(|e| format!("ler SKILL.md arquivado: {e}"))?;
        let item = data
            .archived_skills
            .into_iter()
            .find(|s| s.name == name)
            .ok_or_else(|| format!("skill não encontrada no arquivo: {name}"))?;
        return Ok(SkillDetail { item, content });
    }

    Err(format!("skill não encontrada: {name}"))
}

#[tauri::command]
fn save_skill_meta(
    name: String,
    category: Option<String>,
    tags: Vec<String>,
    tools: Option<Vec<String>>,
    favorite: bool,
    notes: String,
) -> Result<(), String> {
    let root = find_repo_root();
    let is_active = valid_skill_dir(&root, &name).is_ok();
    let is_archived = !is_active && valid_archived_skill_dir(&root, &name).is_ok();

    if !is_active && !is_archived {
        return Err(format!("skill não encontrada: {name}"));
    }

    let mut tags: Vec<String> = tags
        .into_iter()
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
        .collect();
    tags.sort();
    tags.dedup();

    if is_active {
        let file = catalog_path(&root);
        let mut catalog = read_catalog(&file);
        let entry = catalog.skills.entry(name).or_default();
        entry.category = category.filter(|c| !c.is_empty() && c != "uncategorized");
        entry.tags = tags;
        entry.tools = tools;
        entry.favorite = favorite;
        entry.notes = notes;
        entry.updated_at = Some(now_iso());
        catalog.updated_at = Some(now_iso());
        write_catalog(&file, &catalog)?;
    } else {
        let file = archive_catalog_path(&root);
        let mut catalog = read_archive_catalog(&file);
        let entry = catalog.skills.entry(name).or_default();
        entry.category = category.filter(|c| !c.is_empty() && c != "uncategorized");
        entry.tags = tags;
        entry.tools = tools;
        entry.favorite = favorite;
        entry.notes = notes;
        catalog.updated_at = Some(now_iso());
        write_archive_catalog(&file, &catalog)?;
    }

    Ok(())
}

#[tauri::command]
fn save_category(category: Category) -> Result<(), String> {
    let root = find_repo_root();
    if category.id.trim().is_empty() {
        return Err("id da categoria é obrigatório".to_string());
    }
    if !category
        .id
        .chars()
        .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
    {
        return Err("id da categoria deve usar apenas a-z, 0-9 e '-'".to_string());
    }

    let file = catalog_path(&root);
    let mut catalog = read_catalog(&file);

    let mut entry = category;
    entry.label = entry.label.trim().to_string();
    if entry.label.is_empty() {
        return Err("label da categoria é obrigatório".to_string());
    }

    if let Some(existing) = catalog.categories.iter_mut().find(|c| c.id == entry.id) {
        *existing = entry;
    } else {
        catalog.categories.push(entry);
    }

    catalog.categories.sort_by_key(|c| (c.order.unwrap_or(999), c.id.clone()));
    catalog.updated_at = Some(now_iso());
    write_catalog(&file, &catalog)
}

#[tauri::command]
fn delete_category(id: String) -> Result<usize, String> {
    let root = find_repo_root();
    let file = catalog_path(&root);
    let mut catalog = read_catalog(&file);

    let before = catalog.categories.len();
    catalog.categories.retain(|c| c.id != id);
    if catalog.categories.len() == before {
        return Err(format!("categoria não encontrada: {id}"));
    }

    let mut moved = 0usize;
    for skill in catalog.skills.values_mut() {
        if skill.category.as_deref() == Some(id.as_str()) {
            skill.category = None;
            moved += 1;
        }
    }

    catalog.updated_at = Some(now_iso());
    write_catalog(&file, &catalog)?;
    Ok(moved)
}

#[tauri::command]
fn health_report() -> Result<HealthReport, String> {
    let root = find_repo_root();
    let center = skills_dir(&root);
    let catalog = read_catalog(&catalog_path(&root));

    let mut flat = 0usize;
    let mut nested = Vec::new();
    let mut at_names = Vec::new();
    let mut name_mismatches = Vec::new();
    let mut broken_links = Vec::new();
    let mut disk_names: Vec<String> = Vec::new();

    let mut stack = vec![center.clone()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = fs::read_dir(&dir) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            let file_name = entry.file_name().to_string_lossy().to_string();
            let Ok(meta) = fs::symlink_metadata(&path) else { continue };

            if meta.file_type().is_symlink() && !path.exists() {
                broken_links.push(path.to_string_lossy().to_string());
                continue;
            }
            if !path.is_dir() {
                continue;
            }
            if file_name.starts_with('@') && dir == center {
                at_names.push(file_name.clone());
            }

            if path.join("SKILL.md").is_file() {
                if dir == center {
                    flat += 1;
                    disk_names.push(file_name.clone());
                    let content = fs::read_to_string(path.join("SKILL.md")).unwrap_or_default();
                    if let (Some(name), _, _) = parse_frontmatter(&content) {
                        if name != file_name {
                            name_mismatches.push(NameMismatch {
                                dir: file_name.clone(),
                                name,
                            });
                        }
                    }
                } else {
                    nested.push(path.to_string_lossy().to_string());
                }
            }
            stack.push(path);
        }
    }

    disk_names.sort();
    let mut catalog_names: Vec<String> = catalog.skills.keys().cloned().collect();
    catalog_names.sort();

    let missing_in_catalog: Vec<String> = disk_names
        .iter()
        .filter(|n| !catalog.skills.contains_key(*n))
        .cloned()
        .collect();
    let orphan_in_catalog: Vec<String> = catalog_names
        .iter()
        .filter(|n| !disk_names.contains(*n))
        .cloned()
        .collect();

    let ok = nested.is_empty()
        && at_names.is_empty()
        && missing_in_catalog.is_empty()
        && orphan_in_catalog.is_empty()
        && broken_links.is_empty();

    Ok(HealthReport {
        skills_flat: flat,
        nested,
        at_names,
        catalog_total: catalog.skills.len(),
        missing_in_catalog,
        orphan_in_catalog,
        name_mismatches,
        broken_links,
        ok,
    })
}

fn run_script(root: &Path, script: &str, args: &[&str]) -> ScriptResult {
    let output = Command::new(script)
        .args(args)
        .current_dir(root)
        .env("DOTFILES_REPO_ROOT", root)
        .output();

    match output {
        Ok(out) => {
            let mut text = String::from_utf8_lossy(&out.stdout).to_string();
            let stderr = String::from_utf8_lossy(&out.stderr);
            if !stderr.trim().is_empty() {
                if !text.is_empty() {
                    text.push('\n');
                }
                text.push_str(&stderr);
            }
            ScriptResult {
                ok: out.status.success(),
                code: out.status.code().unwrap_or(-1),
                output: text,
            }
        }
        Err(e) => ScriptResult {
            ok: false,
            code: -1,
            output: format!("falha ao executar {script}: {e}"),
        },
    }
}

#[tauri::command]
fn run_check() -> Result<ScriptResult, String> {
    let root = find_repo_root();
    let script = root.join("scripts").join("flatten-agent-skills.sh");
    Ok(run_script(&root, &script.to_string_lossy(), &["--check"]))
}

#[tauri::command]
fn run_bridge(mode: String) -> Result<ScriptResult, String> {
    let root = find_repo_root();
    let script = root.join("scripts").join("install-agent-skills-bridge.sh");
    let args: Vec<&str> = match mode.as_str() {
        "apply" => vec!["--from-catalog"],
        "dry-run" => vec!["--dry-run", "--from-catalog"],
        "doctor" => vec!["--doctor", "--from-catalog"],
        other => return Err(format!("modo inválido: {other}")),
    };
    Ok(run_script(&root, &script.to_string_lossy(), &args))
}

#[tauri::command]
fn open_path(path: String) -> Result<(), String> {
    let root = find_repo_root();
    let target = PathBuf::from(&path);
    let canonical = target
        .canonicalize()
        .map_err(|e| format!("caminho inválido: {e}"))?;

    let center = skills_dir(&root)
        .canonicalize()
        .map_err(|e| format!("acervo inválido: {e}"))?;
    let repo = root
        .canonicalize()
        .map_err(|e| format!("repositório inválido: {e}"))?;

    if !canonical.starts_with(&center) && !canonical.starts_with(&repo) {
        return Err("caminho fora do repositório/acervo".to_string());
    }

    Command::new("xdg-open")
        .arg(&canonical)
        .spawn()
        .map_err(|e| format!("abrir caminho: {e}"))?;
    Ok(())
}

#[tauri::command]
fn create_skill(
    name: String,
    description: String,
    category: Option<String>,
    tools: Option<Vec<String>>,
    template: Option<String>,
) -> Result<(), String> {
    let name = name.trim().to_string();
    if !is_valid_skill_slug(&name) {
        return Err(format!(
            "nome de skill inválido: '{name}'. Use apenas letras minúsculas, números, '.', '_' e '-'."
        ));
    }

    let root = find_repo_root();
    let center = skills_dir(&root);
    let target = center.join(&name);

    if target.parent() != Some(&center) {
        return Err("tentativa de path traversal detectada".to_string());
    }

    if target.exists() {
        return Err(format!("skill já existe no acervo: {name}"));
    }

    let file = catalog_path(&root);
    let mut catalog = read_catalog(&file);
    if catalog.skills.contains_key(&name) {
        return Err(format!("skill já existe no catálogo: {name}"));
    }

    // Criar diretório físico da nova skill
    fs::create_dir_all(&target).map_err(|e| format!("criar diretório da skill: {e}"))?;

    // Gerar conteúdo inicial do SKILL.md de forma segura para YAML
    let desc = description.trim();
    let desc_single_line = desc
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .collect::<Vec<_>>()
        .join(" ");
    let yaml_desc = serde_json::to_string(&desc_single_line).unwrap_or_else(|_| "\"\"".to_string());

    let content = match template.as_deref() {
        Some("empty") => {
            format!("---\nname: {name}\ndescription: {yaml_desc}\n---\n\n# {name}\n")
        }
        _ => {
            let desc_body = if desc_single_line.is_empty() {
                String::new()
            } else {
                format!("{desc_single_line}\n\n")
            };
            format!(
                "---\nname: {name}\ndescription: {yaml_desc}\n---\n\n# {name}\n\n{desc_body}## Overview\n\nDescreva aqui a finalidade desta skill.\n\n## Instructions\n\nInstruções para o agente...\n"
            )
        }
    };

    let skill_md = target.join("SKILL.md");
    fs::write(&skill_md, content).map_err(|e| format!("gravar SKILL.md: {e}"))?;

    // Inserir no catálogo
    let cat_id = category.filter(|c| !c.is_empty() && c != "uncategorized");
    let entry = catalog.skills.entry(name.clone()).or_default();
    entry.category = cat_id;
    entry.tags = Vec::new();
    entry.tools = tools;
    entry.favorite = false;
    entry.notes = String::new();
    entry.updated_at = Some(now_iso());

    catalog.updated_at = Some(now_iso());
    write_catalog(&file, &catalog)?;

    Ok(())
}

fn do_archive_skill(root: &Path, name: &str) -> Result<(), String> {
    let name = name.trim();
    if !is_valid_skill_slug(name) {
        return Err(format!("nome de skill inválido: {name}"));
    }

    let src_dir = valid_skill_dir(root, name)?;
    let arch_dir = archive_dir(root);
    fs::create_dir_all(&arch_dir)
        .map_err(|e| format!("criar pasta do arquivo: {e}"))?;

    let dest_dir = arch_dir.join(name);
    if dest_dir.exists() {
        return Err(format!("já existe uma skill arquivada com o nome: {name}"));
    }

    // 1. Obter metadados do catálogo ativo
    let cat_file = catalog_path(root);
    let mut catalog = read_catalog(&cat_file);
    let meta = catalog.skills.remove(name).unwrap_or_default();
    catalog.updated_at = Some(now_iso());
    write_catalog(&cat_file, &catalog)?;

    // 2. Gravar metadados no catálogo do arquivo
    let arch_cat_file = archive_catalog_path(root);
    let mut arch_catalog = read_archive_catalog(&arch_cat_file);
    let entry = arch_catalog.skills.entry(name.to_string()).or_default();
    entry.category = meta.category;
    entry.tags = meta.tags;
    entry.tools = meta.tools;
    entry.favorite = meta.favorite;
    entry.notes = meta.notes;
    entry.archived_at = Some(now_iso());
    arch_catalog.updated_at = Some(now_iso());
    write_archive_catalog(&arch_cat_file, &arch_catalog)?;

    // 3. Mover diretório
    fs::rename(&src_dir, &dest_dir)
        .map_err(|e| format!("mover skill para a pasta do arquivo: {e}"))?;

    Ok(())
}

fn do_unarchive_skill(root: &Path, name: &str) -> Result<(), String> {
    let name = name.trim();
    if !is_valid_skill_slug(name) {
        return Err(format!("nome de skill inválido: {name}"));
    }

    let src_dir = valid_archived_skill_dir(root, name)?;
    let center = skills_dir(root);
    let dest_dir = center.join(name);
    if dest_dir.exists() {
        return Err(format!("já existe uma skill ativa no acervo com o nome: {name}"));
    }

    // 1. Obter metadados do arquivo
    let arch_cat_file = archive_catalog_path(root);
    let mut arch_catalog = read_archive_catalog(&arch_cat_file);
    let meta = arch_catalog.skills.remove(name).unwrap_or_default();
    arch_catalog.updated_at = Some(now_iso());
    write_archive_catalog(&arch_cat_file, &arch_catalog)?;

    // 2. Restaurar metadados no catálogo ativo
    let cat_file = catalog_path(root);
    let mut catalog = read_catalog(&cat_file);
    let entry = catalog.skills.entry(name.to_string()).or_default();
    entry.category = meta.category;
    entry.tags = meta.tags;
    entry.tools = meta.tools;
    entry.favorite = meta.favorite;
    entry.notes = meta.notes;
    entry.updated_at = Some(now_iso());
    catalog.updated_at = Some(now_iso());
    write_catalog(&cat_file, &catalog)?;

    // 3. Mover diretório de volta para o acervo ativo
    fs::rename(&src_dir, &dest_dir)
        .map_err(|e| format!("restaurar skill para o acervo: {e}"))?;

    Ok(())
}

#[tauri::command]
fn archive_skill(name: String) -> Result<(), String> {
    let root = find_repo_root();
    do_archive_skill(&root, &name)
}

#[tauri::command]
fn unarchive_skill(name: String) -> Result<(), String> {
    let root = find_repo_root();
    do_unarchive_skill(&root, &name)
}

#[tauri::command]
fn save_skill_content(name: String, content: String) -> Result<(), String> {
    let root = find_repo_root();
    if let Ok(dir) = valid_skill_dir(&root, &name) {
        let skill_md = dir.join("SKILL.md");
        fs::write(&skill_md, content).map_err(|e| format!("gravar SKILL.md: {e}"))?;

        let file = catalog_path(&root);
        let mut catalog = read_catalog(&file);
        let entry = catalog.skills.entry(name).or_default();
        entry.updated_at = Some(now_iso());
        catalog.updated_at = Some(now_iso());
        write_catalog(&file, &catalog)?;
        return Ok(());
    }

    if let Ok(dir) = valid_archived_skill_dir(&root, &name) {
        let skill_md = dir.join("SKILL.md");
        fs::write(&skill_md, content).map_err(|e| format!("gravar SKILL.md arquivado: {e}"))?;

        let file = archive_catalog_path(&root);
        let mut catalog = read_archive_catalog(&file);
        catalog.updated_at = Some(now_iso());
        write_archive_catalog(&file, &catalog)?;
        return Ok(());
    }

    Err(format!("skill não encontrada: {name}"))
}

#[tauri::command]
fn delete_skill(name: String) -> Result<(), String> {
    let name = name.trim().to_string();
    if !is_valid_skill_slug(&name) {
        return Err(format!("nome de skill inválido: {name}"));
    }

    let root = find_repo_root();
    let center = skills_dir(&root);
    let target = center.join(&name);

    if target.exists() {
        let sym_meta = fs::symlink_metadata(&target)
            .map_err(|e| format!("ler metadados da skill {name}: {e}"))?;

        if sym_meta.file_type().is_symlink() {
            fs::remove_file(&target)
                .map_err(|e| format!("remover symlink da skill {name}: {e}"))?;
        } else {
            if !target.is_dir() {
                return Err(format!("diretório da skill não encontrado: {name}"));
            }

            // Validação estrita de caminho canônico antes da deleção física
            let canonical_target = target
                .canonicalize()
                .map_err(|e| format!("resolver caminho da skill: {e}"))?;
            let canonical_center = center
                .canonicalize()
                .map_err(|e| format!("resolver acervo de skills: {e}"))?;

            if !canonical_target.starts_with(&canonical_center) || canonical_target == canonical_center {
                return Err("tentativa de excluir diretório fora do acervo de skills".to_string());
            }

            // Remover fisicamente o diretório
            fs::remove_dir_all(&canonical_target)
                .map_err(|e| format!("excluir diretório da skill {name}: {e}"))?;
        }

        // Remover do catálogo
        let file = catalog_path(&root);
        let mut catalog = read_catalog(&file);
        catalog.skills.remove(&name);
        catalog.updated_at = Some(now_iso());
        write_catalog(&file, &catalog)?;

        return Ok(());
    }

    let arch_dir = archive_dir(&root);
    let arch_target = arch_dir.join(&name);

    if arch_target.exists() {
        if !arch_target.is_dir() {
            return Err(format!("diretório da skill arquivada não encontrado: {name}"));
        }

        let canonical_target = arch_target
            .canonicalize()
            .map_err(|e| format!("resolver caminho da skill arquivada: {e}"))?;
        let canonical_arch = arch_dir
            .canonicalize()
            .map_err(|e| format!("resolver pasta do arquivo: {e}"))?;

        if !canonical_target.starts_with(&canonical_arch) || canonical_target == canonical_arch {
            return Err("tentativa de excluir diretório fora da pasta do arquivo".to_string());
        }

        // Remover fisicamente o diretório
        fs::remove_dir_all(&canonical_target)
            .map_err(|e| format!("excluir diretório da skill arquivada {name}: {e}"))?;

        // Remover do catálogo do arquivo
        let file = archive_catalog_path(&root);
        let mut catalog = read_archive_catalog(&file);
        catalog.skills.remove(&name);
        catalog.updated_at = Some(now_iso());
        write_archive_catalog(&file, &catalog)?;

        return Ok(());
    }

    Err(format!("skill não encontrada nem no acervo nem no arquivo: {name}"))
}

fn main() {
    // Diagnóstico sem abrir a janela: skills-gui --print-repo
    if std::env::args().any(|a| a == "--print-repo") {
        let root = find_repo_root();
        println!("repo_root={}", root.display());
        println!("skills_dir={}", skills_dir(&root).display());
        println!("catalog={}", catalog_path(&root).display());
        return;
    }

    // Diagnóstico sem abrir a janela: skills-gui --print-skills
    if std::env::args().any(|a| a == "--print-skills") {
        let root = find_repo_root();
        match load_skills(&root) {
            Ok(data) => {
                println!("skills={}", data.skills.len());
                println!("categories={}", data.categories.len());
                for skill in &data.skills {
                    println!("{}\t{}", skill.name, skill.category.as_deref().unwrap_or("-"));
                }
            }
            Err(err) => {
                eprintln!("erro: {err}");
                std::process::exit(1);
            }
        }
        return;
    }

    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            list_skills,
            get_skill,
            save_skill_meta,
            save_category,
            delete_category,
            health_report,
            run_check,
            run_bridge,
            open_path,
            create_skill,
            save_skill_content,
            delete_skill,
            archive_skill,
            unarchive_skill
        ])
        .run(tauri::generate_context!())
        .expect("erro ao executar o Skills GUI");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_skill_slug() {
        assert!(is_valid_skill_slug("my-skill"));
        assert!(is_valid_skill_slug("git_commit"));
        assert!(is_valid_skill_slug("skill.v2"));
        assert!(is_valid_skill_slug("docker-expert-123"));
        assert!(is_valid_skill_slug("123-skill"));
        assert!(is_valid_skill_slug("a"));
        assert!(is_valid_skill_slug("_knowledge-manager"));
        assert!(is_valid_skill_slug("_dotfiles-config-researcher"));

        // Casos inválidos e tentativas de path traversal
        assert!(!is_valid_skill_slug(""));
        assert!(!is_valid_skill_slug(".."));
        assert!(!is_valid_skill_slug("../../etc"));
        assert!(!is_valid_skill_slug("my..skill"));
        assert!(!is_valid_skill_slug("MySkill"));
        assert!(!is_valid_skill_slug("my skill"));
        assert!(!is_valid_skill_slug("/etc/passwd"));
        assert!(!is_valid_skill_slug("a/b"));
        assert!(!is_valid_skill_slug("a\\b"));
        assert!(!is_valid_skill_slug("-invalid"));
        assert!(!is_valid_skill_slug(".hidden"));
        assert!(!is_valid_skill_slug("skill."));
        assert!(!is_valid_skill_slug("skill "));
    }

    #[test]
    fn test_parse_frontmatter() {
        let content = "---\nname: test-skill\ndescription: \"A test skill with : special\"\n---\n\n# Body\n";
        let (name, desc, closed) = parse_frontmatter(content);
        assert_eq!(name, Some("test-skill".to_string()));
        assert_eq!(desc, Some("A test skill with : special".to_string()));
        assert!(closed);
    }

    #[test]
    fn test_archive_catalog_serde() {
        let mut skills = BTreeMap::new();
        skills.insert(
            "sample-skill".to_string(),
            ArchiveSkillEntry {
                category: Some("utilities".to_string()),
                tags: vec!["test".to_string()],
                tools: None,
                favorite: false,
                notes: "Archived note".to_string(),
                archived_at: Some("2026-11-11T10:00:00Z".to_string()),
            },
        );
        let catalog = ArchiveCatalog {
            version: 1,
            updated_at: Some("2026-11-11T10:00:00Z".to_string()),
            skills,
        };

        let json = serde_json::to_string_pretty(&catalog).expect("serialize archive catalog");
        assert!(json.contains("sample-skill"));
        assert!(json.contains("archivedAt"));

        let deserialized: ArchiveCatalog =
            serde_json::from_str(&json).expect("deserialize archive catalog");
        assert_eq!(deserialized.version, 1);
        assert_eq!(deserialized.skills.len(), 1);
        let entry = deserialized.skills.get("sample-skill").unwrap();
        assert_eq!(entry.category.as_deref(), Some("utilities"));
        assert_eq!(entry.archived_at.as_deref(), Some("2026-11-11T10:00:00Z"));
    }

    #[test]
    fn test_valid_archived_skill_dir_validation() {
        let temp_dir = std::env::temp_dir().join("skills_gui_test_archive_repo");
        let arch_dir = temp_dir.join("apps").join("skills-gui").join("archive");
        let skill_dir = arch_dir.join("test-archived");
        let _ = fs::create_dir_all(&skill_dir);
        let _ = fs::write(skill_dir.join("SKILL.md"), "---\nname: test-archived\n---\n");

        assert!(valid_archived_skill_dir(&temp_dir, "test-archived").is_ok());
        assert!(valid_archived_skill_dir(&temp_dir, "non-existent").is_err());
        assert!(valid_archived_skill_dir(&temp_dir, "../etc").is_err());

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_archive_and_unarchive_lifecycle() {
        let temp_dir = std::env::temp_dir().join("skills_gui_test_lifecycle_repo");
        let _ = fs::remove_dir_all(&temp_dir);

        let active_dir = temp_dir.join("data").join(".agents").join("skills").join("my-test-skill");
        fs::create_dir_all(&active_dir).expect("create active skill dir");
        fs::write(
            active_dir.join("SKILL.md"),
            "---\nname: my-test-skill\ndescription: Test skill\n---\n\n# Overview\n",
        )
        .expect("write SKILL.md");

        let cat_file = catalog_path(&temp_dir);
        let mut initial_cat = Catalog {
            version: 1,
            updated_at: Some("2026-11-11T00:00:00Z".to_string()),
            categories: vec![Category {
                id: "utilities".to_string(),
                label: "Utilities".to_string(),
                order: None,
                color: None,
            }],
            skills: BTreeMap::new(),
        };
        initial_cat.skills.insert(
            "my-test-skill".to_string(),
            CatalogSkill {
                category: Some("utilities".to_string()),
                tags: vec!["demo".to_string()],
                tools: None,
                favorite: true,
                notes: "Initial note".to_string(),
                updated_at: None,
            },
        );
        write_catalog(&cat_file, &initial_cat).expect("write initial catalog");

        // 1. Arquivar
        assert!(do_archive_skill(&temp_dir, "my-test-skill").is_ok());

        // Verificar que sumiu do ativo e apareceu no arquivo
        assert!(!active_dir.exists());
        let archived_skill = archive_dir(&temp_dir).join("my-test-skill");
        assert!(archived_skill.join("SKILL.md").exists());

        // Verificar catálogos
        let cat_after_arch = read_catalog(&cat_file);
        assert!(!cat_after_arch.skills.contains_key("my-test-skill"));

        let arch_cat = read_archive_catalog(&archive_catalog_path(&temp_dir));
        assert!(arch_cat.skills.contains_key("my-test-skill"));
        let arch_meta = arch_cat.skills.get("my-test-skill").unwrap();
        assert_eq!(arch_meta.category.as_deref(), Some("utilities"));
        assert!(arch_meta.favorite);
        assert!(arch_meta.archived_at.is_some());

        // 2. Desarquivar
        assert!(do_unarchive_skill(&temp_dir, "my-test-skill").is_ok());

        // Verificar que retornou ao ativo e sumiu do arquivo
        assert!(active_dir.join("SKILL.md").exists());
        assert!(!archived_skill.exists());

        // Verificar catálogos restaurados
        let cat_after_unarch = read_catalog(&cat_file);
        assert!(cat_after_unarch.skills.contains_key("my-test-skill"));
        let restored_meta = cat_after_unarch.skills.get("my-test-skill").unwrap();
        assert_eq!(restored_meta.category.as_deref(), Some("utilities"));
        assert!(restored_meta.favorite);

        let arch_cat_after = read_archive_catalog(&archive_catalog_path(&temp_dir));
        assert!(!arch_cat_after.skills.contains_key("my-test-skill"));

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
