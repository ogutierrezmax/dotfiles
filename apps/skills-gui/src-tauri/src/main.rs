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
    catalog_path: String,
    skills: Vec<SkillItem>,
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
        });
    }

    items.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    let mut categories = catalog.categories.clone();
    categories.sort_by_key(|c| (c.order.unwrap_or(999), c.id.clone()));

    Ok(AppData {
        repo_root: root.to_string_lossy().to_string(),
        skills_dir: center.to_string_lossy().to_string(),
        catalog_path: catalog_file.to_string_lossy().to_string(),
        skills: items,
        categories,
    })
}

fn valid_skill_dir(root: &Path, name: &str) -> Result<PathBuf, String> {
    if name.is_empty() || name.contains('/') || name.contains('\\') || name.contains("..") {
        return Err(format!("nome de skill inválido: {name}"));
    }
    let path = skills_dir(root).join(name);
    if path.join("SKILL.md").is_file() {
        Ok(path)
    } else {
        Err(format!("skill não encontrada: {name}"))
    }
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
    let dir = valid_skill_dir(&root, &name)?;
    let content = fs::read_to_string(dir.join("SKILL.md"))
        .map_err(|e| format!("ler SKILL.md: {e}"))?;

    let data = load_skills(&root)?;
    let item = data
        .skills
        .into_iter()
        .find(|s| s.name == name)
        .ok_or_else(|| format!("skill não encontrada no acervo: {name}"))?;

    Ok(SkillDetail { item, content })
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
    valid_skill_dir(&root, &name)?;
    let file = catalog_path(&root);
    let mut catalog = read_catalog(&file);

    let mut tags: Vec<String> = tags
        .into_iter()
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
        .collect();
    tags.sort();
    tags.dedup();

    let entry = catalog.skills.entry(name).or_default();
    entry.category = category.filter(|c| !c.is_empty() && c != "uncategorized");
    entry.tags = tags;
    entry.tools = tools;
    entry.favorite = favorite;
    entry.notes = notes;
    entry.updated_at = Some(now_iso());

    catalog.updated_at = Some(now_iso());
    write_catalog(&file, &catalog)
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
            open_path
        ])
        .run(tauri::generate_context!())
        .expect("erro ao executar o Skills GUI");
}
