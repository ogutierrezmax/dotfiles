const TOOLS = ['claude', 'devin', 'antigravity', 'copilot', 'cursor', 'gemini'];
const TOOL_LABELS = {
    claude: 'Claude',
    devin: 'Devin',
    antigravity: 'Antigravity',
    copilot: 'Copilot',
    cursor: 'Cursor',
    gemini: 'Gemini',
};
function escapeHtml(value) {
    return value
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
function formatBytes(bytes) {
    if (bytes < 1024)
        return `${bytes} B`;
    if (bytes < 1024 * 1024)
        return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
function formatDate(iso) {
    if (!iso)
        return '—';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime()))
        return iso;
    return d.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' });
}
class SkillsApp {
    data = null;
    loadError = null;
    filter = { type: 'all' };
    search = '';
    sort = 'name';
    selected = new Set();
    activeSkill = null;
    toastTimer = null;
    // -------------------------------------------------------------------------
    // Infra
    // -------------------------------------------------------------------------
    async invoke(cmd, args) {
        for (let i = 0; i < 25; i++) {
            const w = window;
            if (w.__TAURI__?.core?.invoke) {
                return w.__TAURI__.core.invoke(cmd, args);
            }
            if (w.__TAURI__?.invoke) {
                return w.__TAURI__.invoke(cmd, args);
            }
            if (w.__TAURI_INTERNALS__?.invoke) {
                return w.__TAURI_INTERNALS__.invoke(cmd, args);
            }
            await new Promise((resolve) => setTimeout(resolve, 50));
        }
        return Promise.reject(new Error('Tauri API não detectada no ambiente WebKit'));
    }
    $(id) {
        const el = document.getElementById(id);
        if (!el)
            throw new Error(`elemento ausente: #${id}`);
        return el;
    }
    toast(message, error = false) {
        const el = this.$('toast');
        el.textContent = message;
        el.classList.toggle('error', error);
        el.classList.remove('hidden');
        if (this.toastTimer !== null)
            window.clearTimeout(this.toastTimer);
        this.toastTimer = window.setTimeout(() => el.classList.add('hidden'), 2600);
    }
    // -------------------------------------------------------------------------
    // Bootstrap
    // -------------------------------------------------------------------------
    async init() {
        this.bindEvents();
        await this.refresh();
    }
    bindEvents() {
        this.$('btn-refresh').addEventListener('click', () => void this.refresh());
        this.$('btn-health').addEventListener('click', () => void this.showHealth());
        this.$('btn-bridge-doctor').addEventListener('click', () => void this.runBridge('doctor'));
        this.$('btn-bridge-apply').addEventListener('click', () => void this.runBridge('apply'));
        const search = this.$('search');
        search.addEventListener('input', () => {
            this.search = search.value.trim().toLowerCase();
            this.renderGrid();
        });
        const sort = this.$('sort');
        sort.addEventListener('change', () => {
            this.sort = sort.value;
            this.renderGrid();
        });
        this.$('drawer-backdrop').addEventListener('click', () => this.closeDrawer());
        this.$('bulk-clear').addEventListener('click', () => {
            this.selected.clear();
            this.renderGrid();
        });
        this.$('bulk-apply').addEventListener('click', () => void this.applyBulkCategory());
        this.$('modal').addEventListener('click', (ev) => {
            if (ev.target === this.$('modal'))
                this.closeModal();
        });
        document.addEventListener('keydown', (ev) => {
            if (ev.key === 'Escape') {
                this.closeModal();
                this.closeDrawer();
            }
        });
    }
    async refresh() {
        try {
            this.data = await this.invoke('list_skills');
            this.loadError = null;
            this.$('repo-path').textContent = this.data.skillsDir;
            this.$('repo-path').title = this.data.repoRoot;
            this.renderAll();
        }
        catch (err) {
            this.loadError = String(err);
            this.data = null;
            this.$('repo-path').textContent = 'Falha ao carregar o acervo';
            this.$('repo-path').title = this.loadError;
            this.renderAll();
            this.toast(`Erro ao carregar: ${this.loadError}`, true);
        }
    }
    renderAll() {
        this.renderSidebar();
        this.renderBulkCategories();
        this.renderGrid();
    }
    // -------------------------------------------------------------------------
    // Filtro / ordenação
    // -------------------------------------------------------------------------
    categoryLabel(id) {
        if (!id)
            return 'Sem categoria';
        return this.data?.categories.find((c) => c.id === id)?.label ?? id;
    }
    matchesFilter(skill) {
        switch (this.filter.type) {
            case 'all':
                return true;
            case 'favorite':
                return skill.favorite;
            case 'uncategorized':
                return !skill.category;
            case 'mismatch':
                return skill.nameMismatch;
            case 'category':
                return skill.category === this.filter.value;
            case 'tag':
                return skill.tags.includes(this.filter.value);
            case 'tool':
                return skill.tools === null || skill.tools.includes(this.filter.value);
        }
    }
    visibleSkills() {
        if (!this.data)
            return [];
        const q = this.search;
        const filtered = this.data.skills.filter((skill) => {
            if (!this.matchesFilter(skill))
                return false;
            if (!q)
                return true;
            const haystack = [
                skill.name,
                skill.displayName,
                skill.description,
                skill.notes,
                skill.category ?? '',
                this.categoryLabel(skill.category),
                skill.tags.join(' '),
            ]
                .join(' ')
                .toLowerCase();
            return haystack.includes(q);
        });
        const sorted = [...filtered];
        switch (this.sort) {
            case 'recent':
                sorted.sort((a, b) => b.modifiedAt.localeCompare(a.modifiedAt));
                break;
            case 'category':
                sorted.sort((a, b) => this.categoryLabel(a.category).localeCompare(this.categoryLabel(b.category)) ||
                    a.name.localeCompare(b.name));
                break;
            case 'files':
                sorted.sort((a, b) => b.fileCount - a.fileCount || a.name.localeCompare(b.name));
                break;
            default:
                sorted.sort((a, b) => a.name.localeCompare(b.name));
        }
        return sorted;
    }
    // -------------------------------------------------------------------------
    // Sidebar
    // -------------------------------------------------------------------------
    renderSidebar() {
        if (!this.data)
            return;
        const skills = this.data.skills;
        const total = skills.length;
        const favorites = skills.filter((s) => s.favorite).length;
        const uncategorized = skills.filter((s) => !s.category).length;
        const mismatches = skills.filter((s) => s.nameMismatch).length;
        const tagCounts = new Map();
        for (const skill of skills) {
            for (const tag of skill.tags)
                tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
        }
        const tags = [...tagCounts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
        const toolCounts = new Map();
        for (const tool of TOOLS) {
            toolCounts.set(tool, skills.filter((s) => s.tools === null || s.tools.includes(tool)).length);
        }
        const navItem = (filter, label, count, extra = '') => {
            const active = (() => {
                if (this.filter.type !== filter.type)
                    return false;
                if ('value' in filter && 'value' in this.filter) {
                    return filter.value === this.filter.value;
                }
                return true;
            })();
            return `<div class="nav-item ${active ? 'active' : ''}" data-filter='${escapeHtml(JSON.stringify(filter))}'>
        ${extra}<span class="label">${escapeHtml(label)}</span>
        <span class="badge">${count}</span>
      </div>`;
        };
        const categoryItems = this.data.categories
            .map((cat) => {
            const count = skills.filter((s) => s.category === cat.id).length;
            const color = cat.color ? `style="background-color:${escapeHtml(cat.color)}"` : '';
            const active = this.filter.type === 'category' && this.filter.value === cat.id;
            return `<div class="nav-item ${active ? 'active' : ''}" data-filter='${escapeHtml(JSON.stringify({ type: 'category', value: cat.id }))}'>
          <span class="dot" ${color}></span>
          <span class="label">${escapeHtml(cat.label)}</span>
          <span class="badge">${count}</span>
          <span class="nav-actions">
            <button class="btn-icon" data-edit-cat="${escapeHtml(cat.id)}" title="Editar categoria">✎</button>
            <button class="btn-icon" data-del-cat="${escapeHtml(cat.id)}" title="Excluir categoria">×</button>
          </span>
        </div>`;
        })
            .join('');
        const tagItems = tags
            .map(([tag, count]) => navItem({ type: 'tag', value: tag }, `#${tag}`, count))
            .join('');
        const toolItems = TOOLS.map((tool) => navItem({ type: 'tool', value: tool }, TOOL_LABELS[tool], toolCounts.get(tool) ?? 0)).join('');
        this.$('sidebar').innerHTML = `
      <div class="sidebar-section">
        <div class="sidebar-heading">Visão</div>
        ${navItem({ type: 'all' }, 'Todas as skills', total)}
        ${navItem({ type: 'favorite' }, 'Favoritas', favorites)}
        ${navItem({ type: 'uncategorized' }, 'Sem categoria', uncategorized)}
        ${navItem({ type: 'mismatch' }, 'Nome divergente', mismatches)}
      </div>
      <div class="sidebar-section">
        <div class="sidebar-heading">
          <span>Categorias</span>
          <button class="btn-icon" id="btn-new-category" title="Nova categoria">＋</button>
        </div>
        ${categoryItems || '<div class="field-hint" style="padding:0 4px">Nenhuma categoria</div>'}
      </div>
      <div class="sidebar-section">
        <div class="sidebar-heading">Tags</div>
        ${tagItems || '<div class="field-hint" style="padding:0 4px">Nenhuma tag</div>'}
      </div>
      <div class="sidebar-section">
        <div class="sidebar-heading">Ferramentas (bridge)</div>
        ${toolItems}
        <div class="field-hint" style="padding:6px 4px 0">
          Filtra pela exposição via symlink. Ferramentas que leem o acervo nativamente
          (OpenCode, Codex) enxergam todas as skills independentemente disto.
        </div>
      </div>
    `;
        this.bindSidebar();
    }
    bindSidebar() {
        const sidebar = this.$('sidebar');
        sidebar.querySelectorAll('.nav-item').forEach((item) => {
            item.addEventListener('click', (ev) => {
                const target = ev.target;
                if (target.closest('[data-edit-cat]') || target.closest('[data-del-cat]'))
                    return;
                const raw = item.dataset.filter;
                if (!raw)
                    return;
                this.filter = JSON.parse(raw);
                this.renderSidebar();
                this.renderGrid();
            });
        });
        sidebar.querySelectorAll('[data-edit-cat]').forEach((btn) => {
            btn.addEventListener('click', (ev) => {
                ev.stopPropagation();
                const id = btn.dataset.editCat;
                if (id)
                    this.openCategoryModal(id);
            });
        });
        sidebar.querySelectorAll('[data-del-cat]').forEach((btn) => {
            btn.addEventListener('click', (ev) => {
                ev.stopPropagation();
                const id = btn.dataset.delCat;
                if (id)
                    void this.deleteCategory(id);
            });
        });
        this.$('btn-new-category').addEventListener('click', () => this.openCategoryModal(null));
    }
    // -------------------------------------------------------------------------
    // Grid
    // -------------------------------------------------------------------------
    renderBulkCategories() {
        if (!this.data)
            return;
        const select = this.$('bulk-category');
        const options = [
            '<option value="">Sem categoria</option>',
            ...this.data.categories.map((cat) => `<option value="${escapeHtml(cat.id)}">${escapeHtml(cat.label)}</option>`),
        ];
        select.innerHTML = options.join('');
    }
    renderGrid() {
        const grid = this.$('grid');
        if (!this.data) {
            this.$('count').textContent = '—';
            this.$('bulk-bar').classList.add('hidden');
            grid.innerHTML = `<div class="empty">
        <div class="banner bad" style="text-align:left;max-width:720px;margin:0 auto">
          <strong>Não foi possível carregar o acervo.</strong><br />
          ${escapeHtml(this.loadError ?? 'Erro desconhecido.')}
          <div class="field-hint" style="margin-top:8px">
            Verifique se <code>data/.agents/skills</code> existe no repositório e se o app foi
            aberto pelo launcher <code>~/.local/bin/skills-gui</code> (que exporta
            <code>DOTFILES_REPO_ROOT</code>).
          </div>
        </div>
      </div>`;
            return;
        }
        const skills = this.visibleSkills();
        this.$('count').textContent = `${skills.length} / ${this.data?.skills.length ?? 0}`;
        const bulk = this.$('bulk-bar');
        bulk.classList.toggle('hidden', this.selected.size === 0);
        this.$('bulk-count').textContent = `${this.selected.size} selecionada(s)`;
        if (skills.length === 0) {
            grid.innerHTML = '<div class="empty">Nenhuma skill corresponde ao filtro.</div>';
            return;
        }
        grid.innerHTML = skills
            .map((skill) => {
            const category = skill.category
                ? `<span class="chip cat">${escapeHtml(this.categoryLabel(skill.category))}</span>`
                : '<span class="chip">Sem categoria</span>';
            const tags = skill.tags.map((t) => `<span class="chip">#${escapeHtml(t)}</span>`).join('');
            const tools = skill.tools === null
                ? '<span class="chip tool">todas (bridge)</span>'
                : skill.tools.length === 0
                    ? '<span class="chip warn">sem bridge</span>'
                    : skill.tools
                        .map((t) => `<span class="chip tool">${escapeHtml(TOOL_LABELS[t] ?? t)}</span>`)
                        .join('');
            const mismatch = skill.nameMismatch
                ? `<span class="chip warn" title="Diretório ≠ name do frontmatter">nome ≠ ${escapeHtml(skill.displayName)}</span>`
                : '';
            return `<div class="card ${this.selected.has(skill.name) ? 'selected' : ''}" data-skill="${escapeHtml(skill.name)}">
          <input type="checkbox" class="card-check" data-check="${escapeHtml(skill.name)}" ${this.selected.has(skill.name) ? 'checked' : ''} />
          <div class="card-top">
            <div class="card-title">${escapeHtml(skill.displayName)}</div>
            <button class="star-btn ${skill.favorite ? 'on' : ''}" data-star="${escapeHtml(skill.name)}" title="Favoritar">${skill.favorite ? '★' : '☆'}</button>
          </div>
          ${skill.displayName !== skill.name ? `<div class="card-dir">${escapeHtml(skill.name)}</div>` : ''}
          <div class="card-desc">${escapeHtml(skill.description || 'Sem descrição no frontmatter.')}</div>
          <div class="card-tags">${category}${tags}${tools}${mismatch}</div>
          <div class="card-meta">
            <span>${skill.fileCount} arq.</span>
            <span>${formatBytes(skill.sizeBytes)}</span>
            <span>${formatDate(skill.modifiedAt)}</span>
          </div>
        </div>`;
        })
            .join('');
        this.bindGrid();
    }
    bindGrid() {
        const grid = this.$('grid');
        grid.querySelectorAll('.card').forEach((card) => {
            card.addEventListener('click', (ev) => {
                const target = ev.target;
                const check = target.closest('[data-check]');
                if (check) {
                    ev.stopPropagation();
                    const name = check.dataset.check;
                    if (name) {
                        if (check.checked)
                            this.selected.add(name);
                        else
                            this.selected.delete(name);
                        this.renderGrid();
                    }
                    return;
                }
                const star = target.closest('[data-star]');
                if (star) {
                    ev.stopPropagation();
                    const name = star.dataset.star;
                    if (name)
                        void this.toggleFavorite(name);
                    return;
                }
                const name = card.dataset.skill;
                if (name)
                    void this.openDrawer(name);
            });
        });
    }
    async toggleFavorite(name) {
        const skill = this.data?.skills.find((s) => s.name === name);
        if (!skill)
            return;
        try {
            await this.invoke('save_skill_meta', {
                name,
                category: skill.category,
                tags: skill.tags,
                tools: skill.tools,
                favorite: !skill.favorite,
                notes: skill.notes,
            });
            await this.refresh();
        }
        catch (err) {
            this.toast(`Erro ao favoritar: ${String(err)}`, true);
        }
    }
    async applyBulkCategory() {
        if (!this.data || this.selected.size === 0)
            return;
        const select = this.$('bulk-category');
        const category = select.value || null;
        try {
            for (const name of this.selected) {
                const skill = this.data.skills.find((s) => s.name === name);
                if (!skill)
                    continue;
                await this.invoke('save_skill_meta', {
                    name,
                    category,
                    tags: skill.tags,
                    tools: skill.tools,
                    favorite: skill.favorite,
                    notes: skill.notes,
                });
            }
            this.selected.clear();
            await this.refresh();
            this.toast('Categoria atualizada em lote.');
        }
        catch (err) {
            this.toast(`Erro ao mover: ${String(err)}`, true);
        }
    }
    // -------------------------------------------------------------------------
    // Drawer
    // -------------------------------------------------------------------------
    async openDrawer(name) {
        try {
            const detail = await this.invoke('get_skill', { name });
            this.activeSkill = name;
            this.renderDrawer(detail);
            this.$('drawer').classList.remove('hidden');
            this.$('drawer-backdrop').classList.remove('hidden');
        }
        catch (err) {
            this.toast(`Erro ao abrir skill: ${String(err)}`, true);
        }
    }
    closeDrawer() {
        this.activeSkill = null;
        this.$('drawer').classList.add('hidden');
        this.$('drawer-backdrop').classList.add('hidden');
    }
    renderDrawer(detail) {
        const categories = (this.data?.categories ?? [])
            .map((cat) => `<option value="${escapeHtml(cat.id)}" ${detail.category === cat.id ? 'selected' : ''}>${escapeHtml(cat.label)}</option>`)
            .join('');
        const tools = TOOLS.map((tool) => {
            const checked = detail.tools === null || detail.tools.includes(tool);
            return `<label class="tool-toggle ${checked ? 'on' : ''}">
        <input type="checkbox" data-tool="${tool}" ${checked ? 'checked' : ''} />
        ${escapeHtml(TOOL_LABELS[tool])}
      </label>`;
        }).join('');
        this.$('drawer').innerHTML = `
      <div class="drawer-header">
        <h2>${escapeHtml(detail.displayName)}</h2>
        <button class="btn-icon" id="drawer-close" title="Fechar">✕</button>
      </div>
      <div class="drawer-body">
        <div class="path-row">
          <code>${escapeHtml(detail.path)}</code>
          <button class="btn btn-small" id="open-folder">Abrir pasta</button>
          <button class="btn btn-small" id="open-file">SKILL.md</button>
        </div>
        ${detail.nameMismatch ? `<div class="banner info">Diretório <code>${escapeHtml(detail.name)}</code> difere do frontmatter <code>${escapeHtml(detail.displayName)}</code>. O id do catálogo usa o diretório.</div>` : ''}
        ${!detail.hasFrontmatter ? '<div class="banner bad">Frontmatter ausente ou inválido — o parser não encontrou o bloco <code>---</code>.</div>' : ''}
        <div class="field">
          <label for="d-category">Categoria</label>
          <select id="d-category">
            <option value="">Sem categoria</option>
            ${categories}
          </select>
        </div>
        <div class="field">
          <label for="d-tags">Tags</label>
          <input id="d-tags" type="text" value="${escapeHtml(detail.tags.join(', '))}" placeholder="separadas por vírgula" />
          <span class="field-hint">Ex.: tauri, dotfiles, review</span>
        </div>
        <div class="field">
          <label>Exposição via bridge</label>
          <div class="tools-grid" id="d-tools">${tools}</div>
          <div class="field-hint">
            Marcar todas equivale a <code>null</code> (todas as ferramentas). Desmarcar todas remove
            a skill do bridge. Leitura nativa (OpenCode/Codex) não é afetada.
          </div>
        </div>
        <div class="field">
          <label for="d-notes">Notas</label>
          <textarea id="d-notes" placeholder="Anotações internas sobre esta skill">${escapeHtml(detail.notes)}</textarea>
        </div>
        <div class="field">
          <label>SKILL.md</label>
          <div class="preview">${escapeHtml(detail.content)}</div>
        </div>
      </div>
      <div class="drawer-footer">
        <button class="btn btn-danger" id="drawer-delete-skill" title="Remove a skill do catálogo (não apaga arquivos)">Remover do catálogo</button>
        <button class="btn" id="drawer-cancel">Cancelar</button>
        <button class="btn btn-accent" id="drawer-save">Salvar</button>
      </div>
    `;
        this.$('drawer-close').addEventListener('click', () => this.closeDrawer());
        this.$('drawer-cancel').addEventListener('click', () => this.closeDrawer());
        this.$('open-folder').addEventListener('click', () => void this.openPath(detail.path));
        this.$('open-file').addEventListener('click', () => void this.openPath(`${detail.path}/SKILL.md`));
        this.$('drawer-save').addEventListener('click', () => void this.saveDrawer(detail));
        this.$('drawer-delete-skill').addEventListener('click', () => void this.removeFromCatalog(detail));
        this.$('d-tools')
            .querySelectorAll('input[type="checkbox"]')
            .forEach((input) => {
            input.addEventListener('change', () => {
                input.closest('.tool-toggle')?.classList.toggle('on', input.checked);
            });
        });
    }
    async saveDrawer(detail) {
        const category = this.$('d-category').value || null;
        const tagsRaw = this.$('d-tags').value;
        const notes = this.$('d-notes').value;
        const checked = [
            ...this.$('d-tools').querySelectorAll('input[type="checkbox"]:checked'),
        ].map((i) => i.dataset.tool ?? '');
        const tools = checked.length === TOOLS.length ? null : checked;
        const tags = tagsRaw
            .split(',')
            .map((t) => t.trim())
            .filter(Boolean);
        try {
            await this.invoke('save_skill_meta', {
                name: detail.name,
                category,
                tags,
                tools,
                favorite: detail.favorite,
                notes,
            });
            this.closeDrawer();
            await this.refresh();
            this.toast('Metadados salvos.');
        }
        catch (err) {
            this.toast(`Erro ao salvar: ${String(err)}`, true);
        }
    }
    async removeFromCatalog(detail) {
        const ok = await this.confirmDialog(`Remover "${detail.displayName}" do catálogo? A pasta da skill não é apagada; apenas os metadados saem do catálogo.`);
        if (!ok)
            return;
        try {
            // Não há comando de remoção de metadados: zerar categoria/tags/notas é o
            // equivalente seguro. A entrada permanece para a saúde continuar verde.
            await this.invoke('save_skill_meta', {
                name: detail.name,
                category: null,
                tags: [],
                tools: null,
                favorite: false,
                notes: '',
            });
            this.closeDrawer();
            await this.refresh();
            this.toast('Metadados resetados.');
        }
        catch (err) {
            this.toast(`Erro ao resetar: ${String(err)}`, true);
        }
    }
    // -------------------------------------------------------------------------
    // Categorias
    // -------------------------------------------------------------------------
    openCategoryModal(id) {
        if (!this.data)
            return;
        const existing = id ? this.data.categories.find((c) => c.id === id) : undefined;
        const isEdit = Boolean(existing);
        const body = `
      <div class="field">
        <label for="c-id">Id (slug)</label>
        <input id="c-id" type="text" value="${escapeHtml(existing?.id ?? '')}" ${isEdit ? 'disabled' : ''} placeholder="ex.: code-quality" />
        <span class="field-hint">a-z, 0-9 e hífen. Não pode ser alterado depois de criado.</span>
      </div>
      <div class="field">
        <label for="c-label">Rótulo</label>
        <input id="c-label" type="text" value="${escapeHtml(existing?.label ?? '')}" placeholder="ex.: Code Quality" />
      </div>
      <div class="field">
        <label for="c-color">Cor (opcional)</label>
        <input id="c-color" type="text" value="${escapeHtml(existing?.color ?? '')}" placeholder="#8b5cf6" />
      </div>
      <div class="field">
        <label for="c-order">Ordem (opcional)</label>
        <input id="c-order" type="number" value="${existing?.order ?? ''}" placeholder="ex.: 10" />
      </div>
    `;
        this.showModal(isEdit ? 'Editar categoria' : 'Nova categoria', body, [
            { label: 'Cancelar', action: () => this.closeModal() },
            {
                label: 'Salvar',
                accent: true,
                action: () => void this.saveCategory(isEdit),
            },
        ]);
    }
    async saveCategory(isEdit) {
        const id = this.$('c-id').value.trim();
        const label = this.$('c-label').value.trim();
        const color = this.$('c-color').value.trim();
        const orderRaw = this.$('c-order').value.trim();
        if (!id || !label) {
            this.toast('Id e rótulo são obrigatórios.', true);
            return;
        }
        if (!isEdit && this.data?.categories.some((c) => c.id === id)) {
            this.toast('Já existe uma categoria com esse id.', true);
            return;
        }
        try {
            await this.invoke('save_category', {
                category: {
                    id,
                    label,
                    color: color || undefined,
                    order: orderRaw ? Number(orderRaw) : undefined,
                },
            });
            this.closeModal();
            await this.refresh();
            this.toast(isEdit ? 'Categoria atualizada.' : 'Categoria criada.');
        }
        catch (err) {
            this.toast(`Erro ao salvar categoria: ${String(err)}`, true);
        }
    }
    async deleteCategory(id) {
        const label = this.categoryLabel(id);
        const ok = await this.confirmDialog(`Excluir a categoria "${label}"? As skills dela passam para "Sem categoria".`);
        if (!ok)
            return;
        try {
            const moved = await this.invoke('delete_category', { id });
            if (this.filter.type === 'category' && this.filter.value === id) {
                this.filter = { type: 'all' };
            }
            await this.refresh();
            this.toast(`Categoria excluída. ${moved} skill(s) movidas para "Sem categoria".`);
        }
        catch (err) {
            this.toast(`Erro ao excluir: ${String(err)}`, true);
        }
    }
    // -------------------------------------------------------------------------
    // Saúde / scripts
    // -------------------------------------------------------------------------
    async showHealth() {
        try {
            const report = await this.invoke('health_report');
            const list = (items) => items.length === 0
                ? '<span class="field-hint">nenhum</span>'
                : `<ul>${items.map((i) => `<li>${escapeHtml(i)}</li>`).join('')}</ul>`;
            const body = `
        <div class="banner ${report.ok ? 'ok' : 'bad'}">
          ${report.ok ? 'Estrutura flat e catálogo em dia.' : 'Há pendências de estrutura ou cobertura do catálogo.'}
        </div>
        <div class="health-grid">
          <div class="health-stat ${report.skillsFlat > 0 ? 'good' : 'bad'}">
            <div class="value">${report.skillsFlat}</div>
            <div class="name">Skills flat</div>
          </div>
          <div class="health-stat ${report.catalogTotal === report.skillsFlat ? 'good' : 'bad'}">
            <div class="value">${report.catalogTotal}</div>
            <div class="name">Entradas no catálogo</div>
          </div>
          <div class="health-stat ${report.missingInCatalog.length === 0 ? 'good' : 'bad'}">
            <div class="value">${report.missingInCatalog.length}</div>
            <div class="name">Faltando no catálogo</div>
          </div>
          <div class="health-stat ${report.orphanInCatalog.length === 0 ? 'good' : 'bad'}">
            <div class="value">${report.orphanInCatalog.length}</div>
            <div class="name">Órfãs no catálogo</div>
          </div>
        </div>
        <div class="health-list"><h3>Skills aninhadas (${report.nested.length})</h3>${list(report.nested)}</div>
        <div class="health-list"><h3>Nomes com @ (${report.atNames.length})</h3>${list(report.atNames)}</div>
        <div class="health-list"><h3>Faltando no catálogo (${report.missingInCatalog.length})</h3>${list(report.missingInCatalog)}</div>
        <div class="health-list"><h3>Órfãs no catálogo (${report.orphanInCatalog.length})</h3>${list(report.orphanInCatalog)}</div>
        <div class="health-list"><h3>Nome do diretório ≠ frontmatter (${report.nameMismatches.length})</h3>${report.nameMismatches.length === 0
                ? '<span class="field-hint">nenhum</span>'
                : `<ul>${report.nameMismatches
                    .map((m) => `<li>${escapeHtml(m.dir)} → ${escapeHtml(m.name)}</li>`)
                    .join('')}</ul>`}</div>
        <div class="health-list"><h3>Symlinks quebrados (${report.brokenLinks.length})</h3>${list(report.brokenLinks)}</div>
        <div class="field-hint">As mesmas checagens do <code>scripts/flatten-agent-skills.sh --check</code>.</div>
      `;
            this.showModal('Saúde do acervo', body, [
                { label: 'Rodar --check', action: () => void this.runCheck() },
                { label: 'Fechar', accent: true, action: () => this.closeModal() },
            ]);
        }
        catch (err) {
            this.toast(`Erro na checagem: ${String(err)}`, true);
        }
    }
    async runCheck() {
        try {
            const result = await this.invoke('run_check');
            this.showOutput('flatten-agent-skills.sh --check', result);
        }
        catch (err) {
            this.toast(`Erro ao executar check: ${String(err)}`, true);
        }
    }
    async runBridge(mode) {
        if (mode === 'apply') {
            const ok = await this.confirmDialog('Aplicar o bridge? Isso recria symlinks em ~/.claude, ~/.cursor, ~/.agent, ~/.copilot, ~/.config/devin e ~/.gemini. Diretórios reais são movidos para .bkp antes.');
            if (!ok)
                return;
        }
        try {
            const result = await this.invoke('run_bridge', { mode });
            this.showOutput(`install-agent-skills-bridge.sh${mode === 'apply' ? '' : ` --${mode}`}`, result);
        }
        catch (err) {
            this.toast(`Erro ao executar bridge: ${String(err)}`, true);
        }
    }
    showOutput(title, result) {
        const body = `
      <div class="banner ${result.ok ? 'ok' : 'bad'}">
        ${result.ok ? 'Executado com sucesso.' : 'Falhou (ou encontrou drift).'} Exit code: ${result.code}
      </div>
      <div class="output">${escapeHtml(result.output || '(sem saída)')}</div>
    `;
        this.showModal(title, body, [{ label: 'Fechar', accent: true, action: () => this.closeModal() }]);
    }
    async openPath(path) {
        try {
            await this.invoke('open_path', { path });
        }
        catch (err) {
            this.toast(`Erro ao abrir: ${String(err)}`, true);
        }
    }
    // -------------------------------------------------------------------------
    // Modal genérico
    // -------------------------------------------------------------------------
    showModal(title, bodyHtml, buttons) {
        const footer = buttons
            .map((b, i) => `<button class="btn ${b.accent ? 'btn-accent' : ''}" data-modal-btn="${i}">${escapeHtml(b.label)}</button>`)
            .join('');
        this.$('modal-body').innerHTML = `
      <div class="modal-header">
        <h2>${escapeHtml(title)}</h2>
        <button class="btn-icon" id="modal-close">✕</button>
      </div>
      <div class="modal-body">${bodyHtml}</div>
      <div class="modal-footer">${footer}</div>
    `;
        this.$('modal').classList.remove('hidden');
        this.$('modal-close').addEventListener('click', () => this.closeModal());
        buttons.forEach((b, i) => {
            this.$('modal-body')
                .querySelector(`[data-modal-btn="${i}"]`)
                ?.addEventListener('click', b.action);
        });
    }
    closeModal() {
        this.$('modal').classList.add('hidden');
        this.$('modal-body').innerHTML = '';
    }
    confirmDialog(message) {
        return new Promise((resolve) => {
            const body = `<div class="banner info">${escapeHtml(message)}</div>`;
            this.showModal('Confirmar', body, [
                { label: 'Cancelar', action: () => { this.closeModal(); resolve(false); } },
                { label: 'Confirmar', accent: true, action: () => { this.closeModal(); resolve(true); } },
            ]);
        });
    }
}
const app = new SkillsApp();
window.addEventListener('DOMContentLoaded', () => {
    app.init().catch((err) => {
        console.error(err);
        const toast = document.getElementById('toast');
        if (toast) {
            toast.textContent = `Falha ao iniciar: ${String(err)}`;
            toast.classList.remove('hidden');
            toast.classList.add('error');
        }
    });
});
export {};
