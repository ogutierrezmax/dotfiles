/** Ordenações que começam em ordem decrescente ao serem escolhidas. */
const NUMERIC_SORTS = new Set([
    'recent',
    'files',
    'lines',
    'links',
    'mentions',
    'received',
    'git',
    'size',
]);
/** Peso do estado git para ordenação: pendências primeiro, limpo por último. */
const GIT_WEIGHT = {
    modified: 4,
    untracked: 3,
    ignored: 2,
    clean: 1,
    unknown: 0,
};
/** Rótulo e ícone de cada estado git (o título explica o símbolo). */
const GIT_LABELS = {
    clean: { icon: '✓', label: 'Sem alterações pendentes' },
    modified: { icon: '●', label: 'Alterações não commitadas' },
    untracked: { icon: '?', label: 'Não versionada (untracked)' },
    ignored: { icon: '⊘', label: 'Ignorada pelo .gitignore' },
    unknown: { icon: '—', label: 'git indisponível ou fora de um repositório' },
};
const VIEW_STORAGE_KEY = 'skills-gui.view';
const SIDEBAR_STORAGE_KEY = 'skills-gui.sidebar';
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
function isHttpUrl(value) {
    return /^https?:\/\/\S+$/i.test(value.trim());
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
    sortDir = 'asc';
    viewMode = 'cards';
    sidebarCollapsed = false;
    selected = new Set();
    activeSkill = null;
    activeSkillDetail = null;
    drawerMode = 'view';
    drawerContent = '';
    originalDrawerContent = '';
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
    toast(message, error = false, action) {
        const el = this.$('toast');
        el.innerHTML = '';
        el.classList.toggle('error', error);
        const textSpan = document.createElement('span');
        textSpan.textContent = message;
        el.appendChild(textSpan);
        if (action) {
            const actionLink = document.createElement('a');
            actionLink.className = 'toast-action';
            actionLink.textContent = action.label;
            actionLink.href = '#';
            actionLink.addEventListener('click', (ev) => {
                ev.preventDefault();
                action.onClick();
            });
            el.appendChild(actionLink);
        }
        el.classList.remove('hidden');
        if (this.toastTimer !== null)
            window.clearTimeout(this.toastTimer);
        this.toastTimer = window.setTimeout(() => el.classList.add('hidden'), action ? 5000 : 2800);
    }
    // -------------------------------------------------------------------------
    // Bootstrap
    // -------------------------------------------------------------------------
    async init() {
        this.restoreViewMode();
        this.restoreSidebarState();
        this.bindEvents();
        await this.refresh();
    }
    restoreViewMode() {
        try {
            const saved = window.localStorage.getItem(VIEW_STORAGE_KEY);
            if (saved === 'cards' || saved === 'table') {
                this.viewMode = saved;
            }
        }
        catch {
            // localStorage indisponível: mantém o padrão em cards.
        }
    }
    restoreSidebarState() {
        try {
            this.sidebarCollapsed = window.localStorage.getItem(SIDEBAR_STORAGE_KEY) === 'collapsed';
        }
        catch {
            // localStorage indisponível: mantém o menu expandido.
            this.sidebarCollapsed = false;
        }
        this.applySidebarState();
    }
    toggleSidebar() {
        this.sidebarCollapsed = !this.sidebarCollapsed;
        try {
            window.localStorage.setItem(SIDEBAR_STORAGE_KEY, this.sidebarCollapsed ? 'collapsed' : 'expanded');
        }
        catch {
            // Sem persistência: a troca continua valendo nesta sessão.
        }
        this.applySidebarState();
    }
    applySidebarState() {
        const body = document.querySelector('.app-body');
        body?.classList.toggle('sidebar-collapsed', this.sidebarCollapsed);
        const sidebar = this.$('sidebar');
        sidebar.setAttribute('aria-hidden', String(this.sidebarCollapsed));
        sidebar.toggleAttribute('inert', this.sidebarCollapsed);
        const btn = this.$('btn-sidebar-toggle');
        btn.setAttribute('aria-expanded', String(!this.sidebarCollapsed));
        btn.setAttribute('aria-label', this.sidebarCollapsed ? 'Expandir menu lateral' : 'Recolher menu lateral');
        btn.title = this.sidebarCollapsed
            ? 'Expandir menu lateral (Ctrl+B)'
            : 'Recolher menu lateral (Ctrl+B)';
        btn.classList.toggle('is-collapsed', this.sidebarCollapsed);
    }
    setViewMode(mode) {
        if (this.viewMode === mode)
            return;
        this.viewMode = mode;
        try {
            window.localStorage.setItem(VIEW_STORAGE_KEY, mode);
        }
        catch {
            // Sem persistência: a troca continua valendo nesta sessão.
        }
        this.renderGrid();
    }
    syncViewButtons() {
        const isTable = this.viewMode === 'table';
        const cardsBtn = this.$('view-cards');
        const tableBtn = this.$('view-table');
        cardsBtn.classList.toggle('active', !isTable);
        cardsBtn.setAttribute('aria-pressed', String(!isTable));
        tableBtn.classList.toggle('active', isTable);
        tableBtn.setAttribute('aria-pressed', String(isTable));
    }
    bindEvents() {
        this.$('btn-refresh').addEventListener('click', () => void this.refresh());
        this.$('btn-health').addEventListener('click', () => void this.showHealth());
        this.$('btn-bridge-doctor').addEventListener('click', () => void this.runBridge('doctor'));
        this.$('btn-bridge-apply').addEventListener('click', () => void this.runBridge('apply'));
        this.$('btn-new-skill').addEventListener('click', () => this.openCreateSkillModal());
        const search = this.$('search');
        search.addEventListener('input', () => {
            this.search = search.value.trim().toLowerCase();
            this.renderGrid();
        });
        this.$('view-cards').addEventListener('click', () => this.setViewMode('cards'));
        this.$('view-table').addEventListener('click', () => this.setViewMode('table'));
        this.$('btn-sidebar-toggle').addEventListener('click', () => this.toggleSidebar());
        const sort = this.$('sort');
        sort.addEventListener('change', () => {
            this.sort = sort.value;
            this.sortDir = NUMERIC_SORTS.has(this.sort) ? 'desc' : 'asc';
            this.renderGrid();
        });
        this.$('drawer-backdrop').addEventListener('click', () => this.closeDrawer());
        this.$('bulk-clear').addEventListener('click', () => {
            this.selected.clear();
            this.renderGrid();
        });
        this.$('bulk-apply').addEventListener('click', () => void this.applyBulkCategory());
        this.$('bulk-archive').addEventListener('click', () => void this.applyBulkArchive());
        this.$('bulk-unarchive').addEventListener('click', () => void this.applyBulkUnarchive());
        this.$('modal').addEventListener('click', (ev) => {
            if (ev.target === this.$('modal'))
                this.closeModal();
        });
        document.addEventListener('keydown', (ev) => {
            if ((ev.altKey || ev.ctrlKey) && (ev.key === 'n' || ev.key === 'N')) {
                ev.preventDefault();
                this.openCreateSkillModal();
                return;
            }
            if ((ev.ctrlKey || ev.metaKey) && (ev.key === 's' || ev.key === 'S')) {
                if (this.activeSkill && this.drawerMode === 'edit') {
                    ev.preventDefault();
                    void this.saveDrawerContent();
                    return;
                }
            }
            if ((ev.ctrlKey || ev.metaKey) && (ev.key === 'b' || ev.key === 'B')) {
                const target = ev.target;
                const editing = target instanceof HTMLElement &&
                    (target.tagName === 'INPUT' ||
                        target.tagName === 'TEXTAREA' ||
                        target.isContentEditable);
                if (!editing) {
                    ev.preventDefault();
                    this.toggleSidebar();
                    return;
                }
            }
            if (ev.key === 'Escape') {
                if (!this.$('modal').classList.contains('hidden')) {
                    this.closeModal();
                    return;
                }
                if (!this.$('drawer').classList.contains('hidden')) {
                    this.closeDrawer();
                    return;
                }
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
            case 'archived':
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
        const sourceSkills = this.filter.type === 'archived' ? this.data.archivedSkills : this.data.skills;
        const filtered = sourceSkills.filter((skill) => {
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
        const dir = this.sortDir === 'asc' ? 1 : -1;
        const dateOf = (skill) => this.filter.type === 'archived'
            ? (skill.archivedAt ?? skill.modifiedAt)
            : skill.modifiedAt;
        const primary = (a, b) => {
            switch (this.sort) {
                case 'recent':
                    return dateOf(a).localeCompare(dateOf(b));
                case 'category':
                    return this.categoryLabel(a.category).localeCompare(this.categoryLabel(b.category));
                case 'files':
                    return a.fileCount - b.fileCount;
                case 'size':
                    return a.sizeBytes - b.sizeBytes;
                case 'lines':
                    return a.lineCount - b.lineCount;
                case 'links':
                    return a.linkCount - b.linkCount;
                case 'mentions':
                    return a.mentionCount - b.mentionCount;
                case 'received':
                    return a.mentionedByCount - b.mentionedByCount;
                case 'git':
                    return GIT_WEIGHT[a.gitState] - GIT_WEIGHT[b.gitState];
                default:
                    return a.name.localeCompare(b.name);
            }
        };
        const sorted = [...filtered];
        sorted.sort((a, b) => {
            const result = primary(a, b);
            if (result !== 0)
                return result * dir;
            return a.name.localeCompare(b.name);
        });
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
        const archivedTotal = this.data.archivedSkills.length;
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
        ${navItem({ type: 'archived' }, '📦 Arquivadas', archivedTotal)}
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
            grid.classList.remove('table-mode');
            this.syncViewButtons();
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
        const isArchivedView = this.filter.type === 'archived';
        const totalCount = isArchivedView
            ? (this.data?.archivedSkills.length ?? 0)
            : (this.data?.skills.length ?? 0);
        this.$('count').textContent = isArchivedView
            ? `${skills.length} / ${totalCount} arquivada(s)`
            : `${skills.length} / ${totalCount}`;
        const bulk = this.$('bulk-bar');
        bulk.classList.toggle('hidden', this.selected.size === 0);
        this.$('bulk-count').textContent = `${this.selected.size} selecionada(s)`;
        this.$('bulk-category').classList.toggle('hidden', isArchivedView);
        this.$('bulk-apply').classList.toggle('hidden', isArchivedView);
        this.$('bulk-archive').classList.toggle('hidden', isArchivedView);
        this.$('bulk-unarchive').classList.toggle('hidden', !isArchivedView);
        grid.classList.toggle('table-mode', this.viewMode === 'table');
        this.syncViewButtons();
        if (skills.length === 0) {
            grid.innerHTML = '<div class="empty">Nenhuma skill corresponde ao filtro.</div>';
            return;
        }
        if (this.viewMode === 'table') {
            grid.innerHTML = this.tableHtml(skills);
            this.bindTable(skills);
            return;
        }
        grid.innerHTML = skills
            .map((skill) => {
            const archivedBadge = skill.archived
                ? '<span class="chip archived" title="Skill arquivada na pasta do app">📦 Arquivada</span>'
                : '';
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
            const starBtn = skill.archived
                ? ''
                : `<button class="star-btn ${skill.favorite ? 'on' : ''}" data-star="${escapeHtml(skill.name)}" title="Favoritar">${skill.favorite ? '★' : '☆'}</button>`;
            const dateLabel = skill.archived && skill.archivedAt
                ? `Arq. ${formatDate(skill.archivedAt)}`
                : formatDate(skill.modifiedAt);
            return `<div class="card ${this.selected.has(skill.name) ? 'selected' : ''} ${skill.archived ? 'is-archived' : ''}" data-skill="${escapeHtml(skill.name)}">
          <input type="checkbox" class="card-check" data-check="${escapeHtml(skill.name)}" ${this.selected.has(skill.name) ? 'checked' : ''} />
          <div class="card-top">
            <div class="card-title">${escapeHtml(skill.displayName)}</div>
            ${starBtn}
          </div>
          ${skill.displayName !== skill.name ? `<div class="card-dir">${escapeHtml(skill.name)}</div>` : ''}
          <div class="card-desc">${escapeHtml(skill.description || 'Sem descrição no frontmatter.')}</div>
          <div class="card-tags">${archivedBadge}${category}${tags}${tools}${mismatch}</div>
          <div class="card-meta">
            <span>${skill.fileCount} arq.</span>
            <span>${formatBytes(skill.sizeBytes)}</span>
            <span>${dateLabel}</span>
          </div>
        </div>`;
        })
            .join('');
        this.bindCards();
    }
    tableHtml(skills) {
        const allSelected = skills.length > 0 && skills.every((s) => this.selected.has(s.name));
        const arrow = (key) => {
            if (this.sort !== key)
                return '';
            return this.sortDir === 'asc' ? '▲' : '▼';
        };
        const ariaSort = (key) => {
            if (this.sort !== key)
                return 'none';
            return this.sortDir === 'asc' ? 'ascending' : 'descending';
        };
        const th = (key, label, numeric = false, extra = '') => `<th scope="col" class="${numeric ? 'num' : ''} ${extra}" data-sort="${key}" aria-sort="${ariaSort(key)}" title="Ordenar por ${escapeHtml(label)}">${escapeHtml(label)}<span class="sort-ind">${arrow(key)}</span></th>`;
        const metricCell = (skill, kind, count, label) => count > 0
            ? `<td class="num"><button class="metric-btn" data-metric="${kind}" data-skill="${escapeHtml(skill.name)}" title="Ver ${escapeHtml(label)}">${count}</button></td>`
            : '<td class="num">0</td>';
        const gitCell = (skill) => {
            const state = GIT_LABELS[skill.gitState] ? skill.gitState : 'unknown';
            const info = GIT_LABELS[state];
            return `<td class="col-git"><span class="git-state ${state}" title="${escapeHtml(info.label)}" aria-label="${escapeHtml(info.label)}">${info.icon}</span></td>`;
        };
        const rows = skills
            .map((skill) => {
            const selected = this.selected.has(skill.name);
            const category = skill.category
                ? `<span class="chip cat">${escapeHtml(this.categoryLabel(skill.category))}</span>`
                : '<span class="chip">Sem categoria</span>';
            const archivedBadge = skill.archived
                ? '<span class="chip archived" title="Skill arquivada na pasta do app">📦</span>'
                : '';
            const starBtn = skill.archived
                ? ''
                : `<button class="star-btn ${skill.favorite ? 'on' : ''}" data-star="${escapeHtml(skill.name)}" title="Favoritar">${skill.favorite ? '★' : '☆'}</button>`;
            return `<tr class="${selected ? 'selected' : ''} ${skill.archived ? 'is-archived' : ''}" data-skill="${escapeHtml(skill.name)}">
          <td class="col-check"><input type="checkbox" data-check="${escapeHtml(skill.name)}" ${selected ? 'checked' : ''} aria-label="Selecionar ${escapeHtml(skill.name)}" /></td>
          <td class="col-skill">
            <div class="row-skill">
              ${starBtn}
              <div class="row-skill-titles">
                <span class="row-title">${escapeHtml(skill.displayName)}</span>
                ${skill.displayName !== skill.name
                ? `<span class="row-dir">${escapeHtml(skill.name)}</span>`
                : ''}
              </div>
              ${archivedBadge}
            </div>
          </td>
          <td class="col-category">${category}</td>
          <td class="num">${skill.lineCount}</td>
          ${metricCell(skill, 'links', skill.linkCount, 'links')}
          <td class="col-updated">${formatDate(skill.modifiedAt)}</td>
          ${gitCell(skill)}
          ${metricCell(skill, 'mentions', skill.mentionCount, 'menções')}
          ${metricCell(skill, 'received', skill.mentionedByCount, 'menções recebidas')}
          ${metricCell(skill, 'files', skill.fileCount, 'arquivos')}
          <td class="num col-size">${formatBytes(skill.sizeBytes)}</td>
        </tr>`;
        })
            .join('');
        return `<div class="table-wrap">
      <table class="skills-table">
        <thead>
          <tr>
            <th scope="col" class="col-check"><input type="checkbox" id="select-all" ${allSelected ? 'checked' : ''} aria-label="Selecionar todas as visíveis" /></th>
            ${th('name', 'Skill')}
            ${th('category', 'Categoria', false, 'col-category')}
            ${th('lines', 'Linhas', true)}
            ${th('links', 'Links', true)}
            ${th('recent', 'Atualizado')}
            ${th('git', 'Git', false, 'col-git')}
            ${th('mentions', 'Menções', true)}
            ${th('received', 'Recebidas', true)}
            ${th('files', 'Arq.', true)}
            ${th('size', 'Tamanho', true, 'col-size')}
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;
    }
    bindTable(skills) {
        const grid = this.$('grid');
        grid.querySelectorAll('tr[data-skill]').forEach((row) => {
            row.addEventListener('click', (ev) => {
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
                const metric = target.closest('[data-metric]');
                if (metric) {
                    ev.stopPropagation();
                    const kind = metric.dataset.metric;
                    const name = metric.dataset.skill;
                    if (kind && name)
                        this.openMetricList(name, kind);
                    return;
                }
                const name = row.dataset.skill;
                if (name)
                    void this.openDrawer(name);
            });
        });
        grid.querySelectorAll('th[data-sort]').forEach((th) => {
            th.addEventListener('click', () => {
                const key = th.dataset.sort;
                if (key)
                    this.sortBy(key);
            });
        });
        const selectAll = document.getElementById('select-all');
        selectAll?.addEventListener('change', () => {
            if (selectAll.checked)
                skills.forEach((s) => this.selected.add(s.name));
            else
                skills.forEach((s) => this.selected.delete(s.name));
            this.renderGrid();
        });
    }
    sortBy(key) {
        if (this.sort === key) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        }
        else {
            this.sort = key;
            this.sortDir = NUMERIC_SORTS.has(key) ? 'desc' : 'asc';
        }
        this.$('sort').value = key;
        this.renderGrid();
    }
    bindCards() {
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
    async applyBulkArchive() {
        if (!this.data || this.selected.size === 0)
            return;
        const ok = await this.confirmDialog(`Deseja arquivar as ${this.selected.size} skill(s) selecionada(s)? As pastas serão movidas para apps/skills-gui/archive/.`);
        if (!ok)
            return;
        try {
            for (const name of this.selected) {
                await this.invoke('archive_skill', { name });
            }
            this.selected.clear();
            await this.refresh();
            this.toast('Skill(s) arquivada(s) com sucesso.', false, {
                label: '[🔗 Sincronizar Bridge]',
                onClick: () => void this.runBridge('apply'),
            });
        }
        catch (err) {
            this.toast(`Erro ao arquivar em lote: ${String(err)}`, true);
        }
    }
    async applyBulkUnarchive() {
        if (!this.data || this.selected.size === 0)
            return;
        const ok = await this.confirmDialog(`Deseja restaurar as ${this.selected.size} skill(s) selecionada(s) para o acervo ativo?`);
        if (!ok)
            return;
        try {
            for (const name of this.selected) {
                await this.invoke('unarchive_skill', { name });
            }
            this.selected.clear();
            await this.refresh();
            this.toast('Skill(s) restaurada(s) com sucesso.', false, {
                label: '[🔗 Sincronizar Bridge]',
                onClick: () => void this.runBridge('apply'),
            });
        }
        catch (err) {
            this.toast(`Erro ao desarquivar em lote: ${String(err)}`, true);
        }
    }
    // -------------------------------------------------------------------------
    // Drawer
    // -------------------------------------------------------------------------
    async openDrawer(name) {
        try {
            const detail = await this.invoke('get_skill', { name });
            this.activeSkill = name;
            this.activeSkillDetail = detail;
            this.drawerMode = 'view';
            this.drawerContent = detail.content;
            this.originalDrawerContent = detail.content;
            this.renderDrawer(detail);
            this.$('drawer').classList.remove('hidden');
            this.$('drawer-backdrop').classList.remove('hidden');
        }
        catch (err) {
            this.toast(`Erro ao abrir skill: ${String(err)}`, true);
        }
    }
    isContentDirty() {
        const editor = document.getElementById('skill-content-editor');
        const currentVal = editor && this.drawerMode === 'edit' ? editor.value : this.drawerContent;
        return currentVal !== this.originalDrawerContent;
    }
    isMetadataDirty() {
        if (!this.activeSkillDetail)
            return false;
        const catSelect = document.getElementById('d-category');
        if (catSelect) {
            const currentCat = catSelect.value || null;
            const initialCat = this.activeSkillDetail.category || null;
            if (currentCat !== initialCat)
                return true;
        }
        const tagsInput = document.getElementById('d-tags');
        if (tagsInput) {
            const currentTags = tagsInput.value
                .split(',')
                .map((t) => t.trim())
                .filter(Boolean)
                .sort()
                .join(',');
            const initialTags = [...this.activeSkillDetail.tags]
                .map((t) => t.trim())
                .filter(Boolean)
                .sort()
                .join(',');
            if (currentTags !== initialTags)
                return true;
        }
        const notesTextarea = document.getElementById('d-notes');
        if (notesTextarea) {
            const currentNotes = notesTextarea.value.trim();
            const initialNotes = (this.activeSkillDetail.notes || '').trim();
            if (currentNotes !== initialNotes)
                return true;
        }
        const toolsContainer = document.getElementById('d-tools');
        if (toolsContainer) {
            const checked = [
                ...toolsContainer.querySelectorAll('input[type="checkbox"]:checked'),
            ]
                .map((i) => i.dataset.tool ?? '')
                .filter(Boolean)
                .sort();
            const currentTools = checked.length === TOOLS.length ? null : checked;
            const initialTools = this.activeSkillDetail.tools
                ? [...this.activeSkillDetail.tools].sort()
                : null;
            if (currentTools === null && initialTools !== null)
                return true;
            if (currentTools !== null && initialTools === null)
                return true;
            if (currentTools !== null && initialTools !== null) {
                if (currentTools.join(',') !== initialTools.join(','))
                    return true;
            }
        }
        return false;
    }
    isDrawerDirty() {
        return this.isContentDirty() || this.isMetadataDirty();
    }
    closeDrawer(force = false) {
        if (!force && this.activeSkill && this.isDrawerDirty()) {
            const msg = this.isContentDirty() && this.isMetadataDirty()
                ? 'Há alterações não salvas no SKILL.md e nos metadados. Deseja realmente fechar e descartar?'
                : this.isContentDirty()
                    ? 'Há alterações não salvas no SKILL.md. Deseja realmente fechar e descartar?'
                    : 'Há alterações não salvas nos metadados da skill (categoria, tags, notas ou ferramentas). Deseja realmente fechar e descartar?';
            if (!window.confirm(msg)) {
                return false;
            }
        }
        this.activeSkill = null;
        this.activeSkillDetail = null;
        this.drawerMode = 'view';
        this.drawerContent = '';
        this.originalDrawerContent = '';
        this.$('drawer').classList.add('hidden');
        this.$('drawer-backdrop').classList.add('hidden');
        return true;
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
        ${detail.archived
            ? `<div class="banner info">📦 <strong>Esta skill está arquivada</strong> (pasta: <code>${escapeHtml(detail.path)}</code>). Ela não está ativa no acervo e não é sincronizada pelo bridge.</div>`
            : ''}
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
            ${detail.archived
            ? 'Skills arquivadas não recebem symlinks do bridge.'
            : 'Marcar todas equivale a <code>null</code> (todas as ferramentas). Desmarcar todas remove a skill do bridge. Leitura nativa (OpenCode/Codex) não é afetada.'}
          </div>
        </div>
        <div class="field">
          <label for="d-notes">Notas</label>
          <textarea id="d-notes" placeholder="Anotações internas sobre esta skill">${escapeHtml(detail.notes)}</textarea>
        </div>
        <div class="field" id="skill-content-container"></div>
        ${detail.archived
            ? `<div class="archive-zone">
                <div class="archive-zone-title">↩️ Restaurar do Arquivo</div>
                <div class="archive-zone-desc">
                  Move esta skill de volta para o acervo ativo (<code>data/.agents/skills/</code>) e restaura seus metadados no catálogo.
                </div>
                <button class="btn btn-accent" id="drawer-unarchive-skill">↩️ Desarquivar Skill</button>
              </div>`
            : `<div class="archive-zone">
                <div class="archive-zone-title">📦 Arquivamento</div>
                <div class="archive-zone-desc">
                  Move esta skill para a pasta do arquivo do app (<code>apps/skills-gui/archive/</code>).
                  Ela deixará de ser sincronizada pelas ferramentas de IA e poderá ser restaurada a qualquer momento.
                </div>
                <button class="btn" id="drawer-archive-skill">📦 Arquivar Skill</button>
              </div>`}
        <div class="danger-zone">
          <div class="danger-zone-title">⚠️ Zona de Perigo</div>
          <div class="danger-zone-desc">
            Exclui permanentemente a pasta <code>${escapeHtml(detail.path)}</code> do disco e remove sua entrada do catálogo.
          </div>
          <button class="btn btn-danger" id="drawer-delete-skill" style="align-self: flex-start;">Excluir Skill</button>
        </div>
      </div>
      <div class="drawer-footer">
        <button class="btn" id="drawer-cancel">Fechar</button>
        ${detail.archived
            ? '<button class="btn btn-accent" id="drawer-unarchive-footer">↩️ Desarquivar Skill</button>'
            : ''}
        <button class="btn ${detail.archived ? '' : 'btn-accent'}" id="drawer-save">Salvar Metadados</button>
      </div>
    `;
        this.$('drawer-close').addEventListener('click', () => this.closeDrawer());
        this.$('drawer-cancel').addEventListener('click', () => this.closeDrawer());
        this.$('open-folder').addEventListener('click', () => void this.openPath(detail.path));
        this.$('open-file').addEventListener('click', () => void this.openPath(`${detail.path}/SKILL.md`));
        this.$('drawer-save').addEventListener('click', () => void this.saveDrawer(detail));
        this.$('drawer-delete-skill').addEventListener('click', () => this.openDeleteSkillModal(detail));
        const archiveBtn = document.getElementById('drawer-archive-skill');
        if (archiveBtn) {
            archiveBtn.addEventListener('click', () => this.openArchiveSkillModal(detail));
        }
        const unarchiveBtn = document.getElementById('drawer-unarchive-skill');
        if (unarchiveBtn) {
            unarchiveBtn.addEventListener('click', () => this.openUnarchiveSkillModal(detail));
        }
        const unarchiveFooterBtn = document.getElementById('drawer-unarchive-footer');
        if (unarchiveFooterBtn) {
            unarchiveFooterBtn.addEventListener('click', () => this.openUnarchiveSkillModal(detail));
        }
        this.$('d-tools')
            .querySelectorAll('input[type="checkbox"]')
            .forEach((input) => {
            input.addEventListener('change', () => {
                input.closest('.tool-toggle')?.classList.toggle('on', input.checked);
            });
        });
        this.renderSkillContentSection(detail);
    }
    renderSkillContentSection(detail) {
        const container = document.getElementById('skill-content-container');
        if (!container)
            return;
        const isDirty = this.drawerContent !== this.originalDrawerContent;
        container.innerHTML = `
      <div class="tab-bar">
        <button class="tab-btn ${this.drawerMode === 'view' ? 'active' : ''}" id="tab-view">👁️ Visualizar</button>
        <button class="tab-btn ${this.drawerMode === 'edit' ? 'active' : ''}" id="tab-edit">✏️ Editar</button>
      </div>
      ${this.drawerMode === 'view'
            ? `<div class="preview">${escapeHtml(this.drawerContent)}</div>`
            : `
          <div class="editor-header">
            <span class="editor-shortcuts">Ctrl+S para salvar</span>
            <span id="editor-dirty-indicator" class="modified-badge ${isDirty ? '' : 'hidden'}">● Modificado</span>
            <div style="display:flex;gap:6px;align-items:center;">
              <button class="btn btn-small" id="btn-open-editor" title="Abrir SKILL.md no editor padrão">↗ Abrir no Editor</button>
              <button class="btn btn-small btn-accent" id="btn-save-content">💾 Salvar SKILL.md</button>
            </div>
          </div>
          <textarea class="editor-textarea" id="skill-content-editor" spellcheck="false">${escapeHtml(this.drawerContent)}</textarea>
        `}
    `;
        const tabView = document.getElementById('tab-view');
        const tabEdit = document.getElementById('tab-edit');
        tabView?.addEventListener('click', () => {
            if (this.drawerMode === 'edit') {
                const editor = document.getElementById('skill-content-editor');
                if (editor)
                    this.drawerContent = editor.value;
            }
            this.drawerMode = 'view';
            this.renderSkillContentSection(detail);
        });
        tabEdit?.addEventListener('click', () => {
            this.drawerMode = 'edit';
            this.renderSkillContentSection(detail);
            const editor = document.getElementById('skill-content-editor');
            editor?.focus();
        });
        if (this.drawerMode === 'edit') {
            const editor = document.getElementById('skill-content-editor');
            const saveBtn = document.getElementById('btn-save-content');
            const openEditorBtn = document.getElementById('btn-open-editor');
            saveBtn?.addEventListener('click', () => void this.saveDrawerContent());
            openEditorBtn?.addEventListener('click', () => {
                void this.openPath(`${detail.path}/SKILL.md`);
            });
            editor?.addEventListener('input', () => {
                this.drawerContent = editor.value;
                const dirty = this.drawerContent !== this.originalDrawerContent;
                document.getElementById('editor-dirty-indicator')?.classList.toggle('hidden', !dirty);
            });
            editor?.addEventListener('keydown', (ev) => {
                if ((ev.ctrlKey || ev.metaKey) && (ev.key === 's' || ev.key === 'S')) {
                    ev.preventDefault();
                    ev.stopPropagation();
                    void this.saveDrawerContent();
                }
            });
        }
    }
    async saveDrawerContent() {
        if (!this.activeSkillDetail)
            return;
        const editor = document.getElementById('skill-content-editor');
        const content = editor ? editor.value : this.drawerContent;
        const saveBtn = document.getElementById('btn-save-content');
        if (saveBtn) {
            saveBtn.disabled = true;
            saveBtn.textContent = 'Salvando...';
        }
        try {
            await this.invoke('save_skill_content', {
                name: this.activeSkillDetail.name,
                content,
            });
            this.drawerContent = content;
            this.originalDrawerContent = content;
            this.activeSkillDetail.content = content;
            const dirtyEl = document.getElementById('editor-dirty-indicator');
            if (dirtyEl)
                dirtyEl.classList.add('hidden');
            this.toast('Instruções salvas no arquivo SKILL.md.');
        }
        catch (err) {
            this.toast(`Erro ao salvar SKILL.md: ${String(err)}`, true);
        }
        finally {
            if (saveBtn) {
                saveBtn.disabled = false;
                saveBtn.textContent = '💾 Salvar SKILL.md';
            }
        }
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
            const editor = document.getElementById('skill-content-editor');
            const currentContent = editor && this.drawerMode === 'edit' ? editor.value : this.drawerContent;
            if (currentContent !== this.originalDrawerContent) {
                await this.invoke('save_skill_content', {
                    name: detail.name,
                    content: currentContent,
                });
                this.originalDrawerContent = currentContent;
                this.drawerContent = currentContent;
                detail.content = currentContent;
            }
            await this.invoke('save_skill_meta', {
                name: detail.name,
                category,
                tags,
                tools,
                favorite: detail.favorite,
                notes,
            });
            this.closeDrawer(true);
            await this.refresh();
            this.toast('Metadados salvos.');
        }
        catch (err) {
            this.toast(`Erro ao salvar: ${String(err)}`, true);
        }
    }
    openArchiveSkillModal(detail) {
        const body = `
      <div class="banner info">
        A skill <strong>${escapeHtml(detail.name)}</strong> será movida para a pasta de arquivo do app (<code>apps/skills-gui/archive/${escapeHtml(detail.name)}</code>).
      </div>
      <p style="margin-top:12px;font-size:13px;color:var(--text-secondary)">
        Os metadados (categoria, tags, tools e notas) serão preservados em <code>apps/skills-gui/archive/archive-catalog.json</code>. A skill deixará de ser sincronizada pelo bridge e poderá ser desarquivada a qualquer momento.
      </p>
    `;
        this.showModal('📦 Arquivar Skill', body, [
            { label: 'Cancelar', action: () => this.closeModal() },
            {
                label: 'Confirmar Arquivamento',
                accent: true,
                action: () => void this.archiveSkillSubmit(detail.name),
            },
        ]);
    }
    async archiveSkillSubmit(name) {
        try {
            await this.invoke('archive_skill', { name });
            this.closeModal();
            this.closeDrawer(true);
            await this.refresh();
            this.toast(`Skill '${name}' arquivada com sucesso.`, false, {
                label: '[🔗 Sincronizar Bridge]',
                onClick: () => void this.runBridge('apply'),
            });
        }
        catch (err) {
            this.toast(`Erro ao arquivar skill: ${String(err)}`, true);
        }
    }
    openUnarchiveSkillModal(detail) {
        const body = `
      <div class="banner info">
        A skill <strong>${escapeHtml(detail.name)}</strong> será restaurada para o acervo ativo (<code>data/.agents/skills/${escapeHtml(detail.name)}</code>).
      </div>
      <p style="margin-top:12px;font-size:13px;color:var(--text-secondary)">
        Seus metadados serão reinseridos no catálogo principal de skills e ela voltará a ser elegível para o bridge.
      </p>
    `;
        this.showModal('↩️ Desarquivar Skill', body, [
            { label: 'Cancelar', action: () => this.closeModal() },
            {
                label: 'Restaurar Skill',
                accent: true,
                action: () => void this.unarchiveSkillSubmit(detail.name),
            },
        ]);
    }
    async unarchiveSkillSubmit(name) {
        try {
            await this.invoke('unarchive_skill', { name });
            this.closeModal();
            this.closeDrawer(true);
            await this.refresh();
            this.toast(`Skill '${name}' restaurada com sucesso.`, false, {
                label: '[🔗 Sincronizar Bridge]',
                onClick: () => void this.runBridge('apply'),
            });
        }
        catch (err) {
            this.toast(`Erro ao desarquivar skill: ${String(err)}`, true);
        }
    }
    openDeleteSkillModal(detail) {
        const body = `
      <div class="banner bad">
        <strong>Esta ação é irreversível.</strong><br />
        A pasta <code>${escapeHtml(detail.path)}</code> será excluída permanentemente do disco, sua entrada será removida do catálogo e seus symlinks do bridge serão desvinculados.
      </div>
      <div class="field" style="margin-top:12px">
        <label for="delete-confirm-input">Para confirmar a exclusão, digite <code>${escapeHtml(detail.name)}</code> abaixo:</label>
        <input id="delete-confirm-input" type="text" class="input-slug" placeholder="${escapeHtml(detail.name)}" autocomplete="off" />
      </div>
    `;
        this.showModal('⚠️ Zona de Perigo: Excluir Skill', body, [
            { label: 'Cancelar', action: () => this.closeModal() },
            {
                label: 'Excluir Definitivamente',
                danger: true,
                id: 'btn-confirm-delete',
                disabled: true,
                action: () => void this.deleteSkillSubmit(detail.name),
            },
        ], true, 'modal-delete');
        const input = document.getElementById('delete-confirm-input');
        const confirmBtn = document.getElementById('btn-confirm-delete');
        if (!input || !confirmBtn)
            return;
        input.focus();
        input.addEventListener('input', () => {
            confirmBtn.disabled = input.value.trim() !== detail.name;
        });
        input.addEventListener('keydown', (ev) => {
            if (ev.key === 'Enter' && !confirmBtn.disabled) {
                ev.preventDefault();
                void this.deleteSkillSubmit(detail.name);
            }
        });
    }
    async deleteSkillSubmit(name) {
        const confirmBtn = document.getElementById('btn-confirm-delete');
        if (confirmBtn) {
            confirmBtn.disabled = true;
            confirmBtn.textContent = 'Excluindo...';
        }
        try {
            await this.invoke('delete_skill', { name });
            this.closeModal();
            this.closeDrawer(true);
            await this.refresh();
            this.toast(`Skill '${name}' excluída com sucesso.`, false, {
                label: '[🔗 Sincronizar Bridge]',
                onClick: () => void this.runBridge('apply'),
            });
        }
        catch (err) {
            this.toast(`Erro ao excluir skill: ${String(err)}`, true);
            if (confirmBtn) {
                confirmBtn.disabled = false;
                confirmBtn.textContent = 'Excluir Definitivamente';
            }
        }
    }
    openCreateSkillModal() {
        const initialCat = this.filter.type === 'category' ? this.filter.value : '';
        const catOptions = [
            '<option value="">Sem categoria</option>',
            ...(this.data?.categories ?? []).map((c) => `<option value="${escapeHtml(c.id)}" ${c.id === initialCat ? 'selected' : ''}>${escapeHtml(c.label)}</option>`),
        ].join('');
        const toolsHtml = TOOLS.map((t) => `<label class="tool-toggle on">
        <input type="checkbox" data-create-tool="${t}" checked />
        ${escapeHtml(TOOL_LABELS[t])}
      </label>`).join('');
        const body = `
      <div class="field">
        <label for="new-skill-name">Nome da Skill (slug)</label>
        <input id="new-skill-name" type="text" class="input-slug" placeholder="ex.: docker-expert" autocomplete="off" />
        <div id="slug-feedback" class="slug-feedback"></div>
        <span class="field-hint">Apenas letras minúsculas, números, '.', '_' e '-'. Espaços são convertidos em hífen.</span>
      </div>
      <div class="field">
        <label for="new-skill-desc">Descrição</label>
        <textarea id="new-skill-desc" placeholder="Resumo claro do que este agente especialista faz..."></textarea>
      </div>
      <div class="field">
        <label for="new-skill-category">Categoria</label>
        <select id="new-skill-category">
          ${catOptions}
        </select>
      </div>
      <div class="field">
        <label>Exposição via bridge</label>
        <div class="tools-grid" id="new-skill-tools">${toolsHtml}</div>
        <span class="field-hint">Todas as ferramentas marcadas por padrão.</span>
      </div>
      <div class="field">
        <label for="new-skill-template">Template Inicial</label>
        <select id="new-skill-template">
          <option value="standard">Padrão (Overview + Instructions)</option>
          <option value="empty">Vazio (Apenas frontmatter YAML)</option>
        </select>
      </div>
    `;
        this.showModal('🧩 Criar Nova Skill', body, [
            { label: 'Cancelar', action: () => this.closeModal() },
            {
                label: 'Criar Skill',
                accent: true,
                id: 'btn-submit-create',
                disabled: true,
                action: () => void this.createSkillSubmit(),
            },
        ], false, 'modal-create');
        const nameInput = document.getElementById('new-skill-name');
        const feedback = document.getElementById('slug-feedback');
        const submitBtn = document.getElementById('btn-submit-create');
        const toolsContainer = document.getElementById('new-skill-tools');
        if (!nameInput || !feedback || !submitBtn || !toolsContainer)
            return;
        toolsContainer.querySelectorAll('input[type="checkbox"]').forEach((input) => {
            input.addEventListener('change', () => {
                input.closest('.tool-toggle')?.classList.toggle('on', input.checked);
            });
        });
        const validateSlug = () => {
            let val = nameInput.value;
            const transformed = val.toLowerCase().replace(/\s+/g, '-');
            if (transformed !== val) {
                nameInput.value = transformed;
                val = transformed;
            }
            val = val.trim();
            if (!val) {
                nameInput.classList.remove('valid', 'invalid');
                feedback.className = 'slug-feedback';
                feedback.textContent = '';
                submitBtn.disabled = true;
                return false;
            }
            const slugRegex = /^[a-z0-9][a-z0-9._-]*$/;
            if (!slugRegex.test(val) || val.includes('..')) {
                nameInput.classList.add('invalid');
                nameInput.classList.remove('valid');
                feedback.className = 'slug-feedback invalid';
                feedback.textContent = 'Use apenas a-z, 0-9, "-", "_" e "." iniciando com letra ou número.';
                submitBtn.disabled = true;
                return false;
            }
            const exists = this.data?.skills.some((s) => s.name === val);
            if (exists) {
                nameInput.classList.add('invalid');
                nameInput.classList.remove('valid');
                feedback.className = 'slug-feedback invalid';
                feedback.textContent = 'Nome já em uso no acervo de skills.';
                submitBtn.disabled = true;
                return false;
            }
            nameInput.classList.remove('invalid');
            nameInput.classList.add('valid');
            feedback.className = 'slug-feedback valid';
            feedback.textContent = '✓ Nome disponível.';
            submitBtn.disabled = false;
            return true;
        };
        nameInput.addEventListener('input', validateSlug);
        nameInput.addEventListener('keydown', (ev) => {
            if (ev.key === 'Enter') {
                ev.preventDefault();
                if (validateSlug()) {
                    void this.createSkillSubmit();
                }
            }
        });
        nameInput.focus();
    }
    async createSkillSubmit() {
        const nameInput = document.getElementById('new-skill-name');
        const descInput = document.getElementById('new-skill-desc');
        const catInput = document.getElementById('new-skill-category');
        const templateInput = document.getElementById('new-skill-template');
        const submitBtn = document.getElementById('btn-submit-create');
        if (!nameInput || !descInput || !catInput || !templateInput)
            return;
        const name = nameInput.value.trim();
        const description = descInput.value.trim();
        const category = catInput.value || null;
        const template = templateInput.value;
        const checkedTools = [
            ...document.querySelectorAll('#new-skill-tools input[type="checkbox"]:checked'),
        ].map((i) => i.dataset.createTool ?? '');
        const tools = checkedTools.length === TOOLS.length ? null : checkedTools;
        const modalEl = this.$('modal-body');
        const formElements = modalEl.querySelectorAll('input, textarea, select, button');
        formElements.forEach((el) => {
            el.disabled = true;
        });
        if (submitBtn) {
            submitBtn.textContent = 'Criando...';
        }
        try {
            await this.invoke('create_skill', {
                name,
                description,
                category,
                tools,
                template,
            });
            this.closeModal();
            await this.refresh();
            await this.openDrawer(name);
            this.toast(`Skill '${name}' criada com sucesso.`, false, {
                label: '[🔗 Aplicar bridge]',
                onClick: () => void this.runBridge('apply'),
            });
        }
        catch (err) {
            this.toast(`Erro ao criar skill: ${String(err)}`, true);
            formElements.forEach((el) => {
                el.disabled = false;
            });
            if (submitBtn) {
                submitBtn.textContent = 'Criar Skill';
            }
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
    findSkill(name) {
        if (!this.data)
            return undefined;
        return (this.data.skills.find((skill) => skill.name === name) ??
            this.data.archivedSkills.find((skill) => skill.name === name));
    }
    async openUrl(url) {
        if (!isHttpUrl(url)) {
            this.toast('Só é possível abrir links http(s).', true);
            return;
        }
        try {
            await this.invoke('open_url', { url });
        }
        catch (err) {
            this.toast(`Erro ao abrir link: ${String(err)}`, true);
        }
    }
    /** Lista detalhada de uma métrica da tabela (links, menções, recebidas, arquivos). */
    openMetricList(name, kind) {
        const skill = this.findSkill(name);
        if (!skill) {
            this.toast('Skill não encontrada.', true);
            return;
        }
        const close = [{ label: 'Fechar', accent: true, action: () => this.closeModal() }];
        const body = this.$('modal-body');
        if (kind === 'links') {
            const links = skill.linkTargets;
            const html = links.length
                ? `<ul class="metric-list">${links
                    .map((link, i) => isHttpUrl(link)
                    ? `<li class="metric-item"><button class="metric-link" data-link-index="${i}">${escapeHtml(link)}</button></li>`
                    : `<li class="metric-item"><code class="metric-path">${escapeHtml(link)}</code></li>`)
                    .join('')}</ul>
          <p class="field-hint">Links relativos aparecem como texto e não abrem no navegador.</p>`
                : '<div class="empty">Nenhum link.</div>';
            this.showModal(`🔗 ${links.length} link(s) — ${skill.name}`, html, close, false, 'modal-metric');
            body.querySelectorAll('[data-link-index]').forEach((el) => {
                el.addEventListener('click', () => {
                    const url = links[Number(el.dataset.linkIndex)];
                    if (url)
                        void this.openUrl(url);
                });
            });
            return;
        }
        if (kind === 'mentions' || kind === 'received') {
            const names = kind === 'mentions' ? skill.mentions : skill.mentionedBy;
            const title = kind === 'mentions'
                ? `🗣 ${names.length} menção(ões) — ${skill.name}`
                : `📥 ${names.length} recebida(s) — ${skill.name}`;
            const hint = kind === 'mentions'
                ? 'Skills mencionadas no conteúdo desta.'
                : 'Skills que mencionam esta.';
            const html = names.length
                ? `<p class="field-hint">${hint}</p><ul class="metric-list">${names
                    .map((mentioned) => {
                    const target = this.findSkill(mentioned);
                    const label = target && target.displayName !== mentioned
                        ? `${escapeHtml(target.displayName)} <span class="metric-path">${escapeHtml(mentioned)}</span>`
                        : escapeHtml(mentioned);
                    return `<li class="metric-item"><button class="metric-link" data-jump="${escapeHtml(mentioned)}">${label}</button></li>`;
                })
                    .join('')}</ul>`
                : '<div class="empty">Nada aqui.</div>';
            this.showModal(title, html, close, false, 'modal-metric');
            body.querySelectorAll('[data-jump]').forEach((el) => {
                el.addEventListener('click', () => {
                    const jump = el.dataset.jump;
                    if (!jump)
                        return;
                    this.closeModal();
                    void this.openDrawer(jump);
                });
            });
            return;
        }
        const files = skill.files;
        const total = files.reduce((sum, file) => sum + file.sizeBytes, 0);
        const html = files.length
            ? `<p class="field-hint">${formatBytes(total)} no total. Clique em um arquivo para abrir.</p>
        <ul class="metric-list">${files
                .map((file, i) => `<li class="metric-item"><button class="metric-link" data-file-index="${i}"><span class="metric-path">${escapeHtml(file.path)}</span><span class="metric-size">${formatBytes(file.sizeBytes)}</span></button></li>`)
                .join('')}</ul>`
            : '<div class="empty">Nenhum arquivo.</div>';
        this.showModal(`📄 ${files.length} arquivo(s) — ${skill.name}`, html, [{ label: 'Abrir pasta', action: () => void this.openPath(skill.path) }, ...close], false, 'modal-metric');
        body.querySelectorAll('[data-file-index]').forEach((el) => {
            el.addEventListener('click', () => {
                const file = files[Number(el.dataset.fileIndex)];
                if (file)
                    void this.openPath(`${skill.path}/${file.path}`);
            });
        });
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
    showModal(title, bodyHtml, buttons, isDanger = false, customClass) {
        const modalEl = this.$('modal-body');
        modalEl.setAttribute('role', 'dialog');
        modalEl.setAttribute('aria-modal', 'true');
        modalEl.classList.toggle('modal-danger', isDanger);
        if (customClass) {
            modalEl.classList.add(customClass);
        }
        const footer = buttons
            .map((b, i) => `<button class="btn ${b.accent ? 'btn-accent' : ''} ${b.danger ? 'btn-danger-solid' : ''}" ${b.id ? `id="${b.id}"` : ''} ${b.disabled ? 'disabled' : ''} data-modal-btn="${i}">${escapeHtml(b.label)}</button>`)
            .join('');
        modalEl.innerHTML = `
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
            modalEl
                .querySelector(`[data-modal-btn="${i}"]`)
                ?.addEventListener('click', b.action);
        });
    }
    closeModal() {
        this.$('modal').classList.add('hidden');
        this.$('modal-body').classList.remove('modal-danger', 'modal-create', 'modal-delete', 'modal-metric');
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
