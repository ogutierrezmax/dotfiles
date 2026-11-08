// Global App State
let currentRelPath = '';
let currentItems = [];
let selectedRelPath = null;
let activeFilter = 'all';
let activeLocFilter = 'all';
let searchQuery = '';
let activeDrawerTab = 'app';
let lastDashboard = null;
let isDrawerCollapsed = false;
const expandedFolders = new Set();
let selectedQueueFolder = null;
let folderQueueFilter = 'all';
let folderSearchQuery = '';
// Helpers
async function invoke(cmd, args) {
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
    throw new Error('Tauri API não disponível');
}
function formatBytes(bytes) {
    if (bytes === 0)
        return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
}
function formatSpeed(bytesPerSec) {
    if (bytesPerSec <= 0)
        return '0 KB/s';
    return `${formatBytes(bytesPerSec)}/s`;
}
function showToast(msg, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container)
        return;
    const toast = document.createElement('div');
    toast.className = `toast text-${type === 'error' ? 'danger' : type === 'success' ? 'success' : 'info'}`;
    toast.textContent = msg;
    container.appendChild(toast);
    setTimeout(() => toast.remove(), 4000);
}
// Lifecycle Initialization
function startApp() {
    init().catch((err) => {
        console.error('Falha na inicialização:', err);
        showToast(String(err), 'error');
    });
}
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startApp);
}
else {
    startApp();
}
async function init() {
    setupEventListeners();
    setupResizers();
    setupDragAndDrop();
    await Promise.all([loadDirectory(''), refreshDashboard()]);
    // Polling loop: 2s interval
    setInterval(() => {
        refreshDashboard().catch(() => { });
    }, 2000);
}
function setupEventListeners() {
    // Up Button & Shortcut
    document.getElementById('btn-nav-up')?.addEventListener('click', () => {
        navigateUp();
    });
    window.addEventListener('keydown', (e) => {
        if (e.altKey && e.key === 'ArrowUp') {
            e.preventDefault();
            navigateUp();
        }
    });
    // Refresh Button
    document.getElementById('btn-refresh')?.addEventListener('click', async () => {
        await Promise.all([loadDirectory(currentRelPath), refreshDashboard()]);
        showToast('Atualizado com sucesso', 'success');
    });
    // Open Dolphin Button
    document.getElementById('btn-open-dolphin')?.addEventListener('click', async () => {
        try {
            await invoke('open_in_system', { relPath: currentRelPath, reveal: false });
        }
        catch (e) {
            showToast(String(e), 'error');
        }
    });
    // Upload Trigger (HTML file input fallback)
    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.multiple = true;
    fileInput.style.display = 'none';
    document.body.appendChild(fileInput);
    document.getElementById('btn-upload')?.addEventListener('click', () => {
        fileInput.click();
    });
    fileInput.addEventListener('change', async () => {
        if (!fileInput.files || fileInput.files.length === 0)
            return;
        const paths = [];
        for (let i = 0; i < fileInput.files.length; i++) {
            const file = fileInput.files[i];
            // On web/Tauri with file picker, path property is available
            const pathVal = file.path;
            if (pathVal) {
                paths.push(pathVal);
            }
        }
        if (paths.length > 0) {
            await enqueueUploadFiles(paths);
        }
        else {
            const manual = prompt('Caminho absoluto do arquivo a ser enviado (ou arraste e solte o arquivo na janela):');
            if (manual && manual.trim()) {
                await enqueueUploadFiles([manual.trim()]);
            }
        }
        fileInput.value = '';
    });
    // New Folder Modal
    const modalFolder = document.getElementById('modal-folder');
    const inputFolderName = document.getElementById('input-folder-name');
    document.getElementById('btn-new-folder')?.addEventListener('click', () => {
        if (isProtectedBackupPath(currentRelPath)) {
            showToast('Backup-SanDisk-1TB é gerenciado automaticamente pelo rclone-backup (somente leitura)', 'info');
            return;
        }
        inputFolderName.value = '';
        modalFolder?.classList.remove('hidden');
        inputFolderName.focus();
    });
    document.getElementById('modal-folder-close')?.addEventListener('click', () => {
        modalFolder?.classList.add('hidden');
    });
    document.getElementById('btn-folder-cancel')?.addEventListener('click', () => {
        modalFolder?.classList.add('hidden');
    });
    document.getElementById('btn-folder-confirm')?.addEventListener('click', async () => {
        const name = inputFolderName.value.trim();
        if (!name)
            return;
        try {
            await invoke('create_folder', { relPath: currentRelPath, folderName: name });
            modalFolder?.classList.add('hidden');
            showToast(`Pasta "${name}" criada`, 'success');
            await loadDirectory(currentRelPath);
        }
        catch (e) {
            showToast(String(e), 'error');
        }
    });
    // Rename Modal
    const modalRename = document.getElementById('modal-rename');
    const inputRenameRel = document.getElementById('input-rename-rel');
    const inputRenameName = document.getElementById('input-rename-name');
    document.getElementById('modal-rename-close')?.addEventListener('click', () => {
        modalRename?.classList.add('hidden');
    });
    document.getElementById('btn-rename-cancel')?.addEventListener('click', () => {
        modalRename?.classList.add('hidden');
    });
    document.getElementById('btn-rename-confirm')?.addEventListener('click', async () => {
        const rel = inputRenameRel.value;
        const newName = inputRenameName.value.trim();
        if (!rel || !newName)
            return;
        try {
            await invoke('rename_entry', { relPath: rel, newName });
            modalRename?.classList.add('hidden');
            showToast('Renomeado com sucesso', 'success');
            await loadDirectory(currentRelPath);
        }
        catch (e) {
            showToast(String(e), 'error');
        }
    });
    // Search Input
    const searchInput = document.getElementById('search-input');
    searchInput?.addEventListener('input', () => {
        searchQuery = searchInput.value.toLowerCase().trim();
        renderFilesTable();
    });
    // Pill Filter Buttons (State)
    const statePills = document.querySelectorAll('.filter-pills:not(.loc-pills) .pill-btn');
    statePills.forEach((btn) => {
        btn.addEventListener('click', () => {
            statePills.forEach((b) => b.classList.remove('active'));
            btn.classList.add('active');
            activeFilter = btn.getAttribute('data-filter') || 'all';
            renderFilesTable();
        });
    });
    // Location Filter Pills
    const locPills = document.querySelectorAll('.btn-loc-pill');
    locPills.forEach((btn) => {
        btn.addEventListener('click', () => {
            locPills.forEach((b) => b.classList.remove('active'));
            btn.classList.add('active');
            activeLocFilter = btn.getAttribute('data-loc') || 'all';
            renderFilesTable();
        });
    });
    // Preview Pane Close & Open
    document.getElementById('btn-preview-close')?.addEventListener('click', () => {
        closePreview();
    });
    document.getElementById('btn-preview-open')?.addEventListener('click', async () => {
        if (selectedRelPath) {
            try {
                await invoke('open_in_system', { relPath: selectedRelPath, reveal: false });
            }
            catch (e) {
                showToast(String(e), 'error');
            }
        }
    });
    // Drawer Toggle & Tabs
    const drawer = document.getElementById('transfers-drawer');
    document.getElementById('drawer-toggle')?.addEventListener('click', (e) => {
        if (e.target.closest('#btn-clear-completed'))
            return;
        isDrawerCollapsed = !isDrawerCollapsed;
        drawer?.classList.toggle('collapsed', isDrawerCollapsed);
    });
    document.getElementById('btn-clear-completed')?.addEventListener('click', async () => {
        try {
            await invoke('clear_completed_uploads');
            await refreshDashboard();
            showToast('Itens concluídos limpos', 'info');
        }
        catch (e) {
            showToast(String(e), 'error');
        }
    });
    const drawerTabs = document.querySelectorAll('.drawer-tab');
    drawerTabs.forEach((tab) => {
        tab.addEventListener('click', () => {
            drawerTabs.forEach((t) => t.classList.remove('active'));
            tab.classList.add('active');
            activeDrawerTab = tab.getAttribute('data-tab') || 'app';
            renderDrawerTransfers();
        });
    });
}
function setupResizers() {
    const previewPane = document.getElementById('preview-pane');
    const resizerPreview = document.getElementById('resizer-preview');
    const drawerContent = document.getElementById('drawer-content');
    const resizerDrawer = document.getElementById('resizer-drawer');
    // Restore saved dimensions
    const savedWidth = localStorage.getItem('gdrive_preview_width');
    if (savedWidth && previewPane) {
        const w = parseInt(savedWidth, 10);
        if (!isNaN(w) && w >= 220) {
            previewPane.style.width = `${w}px`;
        }
    }
    const savedHeight = localStorage.getItem('gdrive_drawer_height');
    if (savedHeight && drawerContent) {
        const h = parseInt(savedHeight, 10);
        if (!isNaN(h) && h >= 60) {
            drawerContent.style.height = `${h}px`;
        }
    }
    // Width Resizer (Preview)
    if (resizerPreview && previewPane) {
        let startX = 0;
        let startWidth = 0;
        let isDragging = false;
        resizerPreview.addEventListener('mousedown', (e) => {
            e.preventDefault();
            startX = e.clientX;
            startWidth = previewPane.getBoundingClientRect().width;
            isDragging = true;
            document.body.classList.add('resizing-col');
            resizerPreview.classList.add('active');
        });
        window.addEventListener('mousemove', (e) => {
            if (!isDragging)
                return;
            const delta = startX - e.clientX;
            const maxW = Math.max(300, window.innerWidth - 260);
            const newWidth = Math.max(220, Math.min(maxW, startWidth + delta));
            previewPane.style.width = `${newWidth}px`;
        });
        window.addEventListener('mouseup', () => {
            if (isDragging) {
                isDragging = false;
                document.body.classList.remove('resizing-col');
                resizerPreview.classList.remove('active');
                const finalW = parseInt(previewPane.style.width, 10);
                if (!isNaN(finalW)) {
                    localStorage.setItem('gdrive_preview_width', String(finalW));
                }
            }
        });
    }
    // Height Resizer (Drawer)
    if (resizerDrawer && drawerContent) {
        let startY = 0;
        let startHeight = 0;
        let isDragging = false;
        resizerDrawer.addEventListener('mousedown', (e) => {
            e.preventDefault();
            startY = e.clientY;
            startHeight = drawerContent.getBoundingClientRect().height;
            isDragging = true;
            document.body.classList.add('resizing-row');
            resizerDrawer.classList.add('active');
        });
        window.addEventListener('mousemove', (e) => {
            if (!isDragging)
                return;
            const delta = startY - e.clientY;
            const maxH = Math.max(100, window.innerHeight - 180);
            const newHeight = Math.max(60, Math.min(maxH, startHeight + delta));
            drawerContent.style.height = `${newHeight}px`;
        });
        window.addEventListener('mouseup', () => {
            if (isDragging) {
                isDragging = false;
                document.body.classList.remove('resizing-row');
                resizerDrawer.classList.remove('active');
                const finalH = parseInt(drawerContent.style.height, 10);
                if (!isNaN(finalH)) {
                    localStorage.setItem('gdrive_drawer_height', String(finalH));
                }
            }
        });
    }
}
function setupDragAndDrop() {
    const dropZone = document.getElementById('drop-zone');
    const dropOverlay = document.getElementById('drop-overlay');
    // Tauri Native Drag & Drop listener if supported
    if (window.__TAURI__?.event) {
        window.__TAURI__.event.listen('tauri://drag-drop', async (evt) => {
            dropOverlay?.classList.add('hidden');
            if (evt.payload?.paths?.length) {
                await enqueueUploadFiles(evt.payload.paths);
            }
        }).catch(() => { });
    }
    // HTML5 Drag Events
    window.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropOverlay?.classList.remove('hidden');
    });
    window.addEventListener('dragleave', (e) => {
        if (e.relatedTarget === null) {
            dropOverlay?.classList.add('hidden');
        }
    });
    dropZone?.addEventListener('drop', async (e) => {
        e.preventDefault();
        dropOverlay?.classList.add('hidden');
    });
}
async function enqueueUploadFiles(sourcePaths) {
    try {
        const items = await invoke('enqueue_uploads', {
            sourcePaths,
            targetRelDir: currentRelPath,
        });
        showToast(`${items.length} arquivo(s) adicionados à fila de upload`, 'success');
        await Promise.all([loadDirectory(currentRelPath), refreshDashboard()]);
    }
    catch (e) {
        showToast(String(e), 'error');
    }
}
// Directory Loader
function itemsSignature(items) {
    return items
        .map((i) => `${i.rel_path}|${i.is_dir}|${i.size}|${i.modified_str}|${i.location}|${i.sync_state}|${i.progress_percent}|${i.status_note}`)
        .join('\n');
}
async function loadDirectory(relPath) {
    currentRelPath = relPath;
    renderBreadcrumbs();
    const tbody = document.getElementById('files-table-body');
    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">Carregando arquivos...</td></tr>';
    }
    try {
        currentItems = await invoke('list_directory', { relPath });
        updateSummaryCounts();
        renderFilesTable();
    }
    catch (e) {
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger">Erro: ${e}</td></tr>`;
        }
    }
}
async function refreshCurrentDirectorySilent() {
    const reqPath = currentRelPath;
    try {
        const items = await invoke('list_directory', { relPath: reqPath });
        if (reqPath !== currentRelPath)
            return;
        if (itemsSignature(items) !== itemsSignature(currentItems)) {
            currentItems = items;
            updateSummaryCounts();
            renderFilesTable();
        }
    }
    catch {
        // Ignore transient poll errors
    }
}
function updateSummaryCounts() {
    const total = currentItems.length;
    let waiting = 0;
    let uploading = 0;
    let uploaded = 0;
    for (const it of currentItems) {
        if (it.sync_state === 'aguardando')
            waiting++;
        else if (it.sync_state === 'uploading') {
            uploading++;
            if (it.is_dir && it.status_note.toLowerCase().includes('aguardando')) {
                waiting++;
            }
        }
        else if (it.sync_state === 'uploaded')
            uploaded++;
    }
    const elTotal = document.getElementById('sum-total');
    const elWaiting = document.getElementById('sum-waiting');
    const elUploading = document.getElementById('sum-uploading');
    const elUploaded = document.getElementById('sum-uploaded');
    if (elTotal)
        elTotal.textContent = String(total);
    if (elWaiting)
        elWaiting.textContent = String(waiting);
    if (elUploading)
        elUploading.textContent = String(uploading);
    if (elUploaded)
        elUploaded.textContent = String(uploaded);
}
function navigateUp() {
    if (!currentRelPath)
        return;
    const clean = currentRelPath.trim().replace(/^\/+|\/+$/g, '');
    if (!clean.includes('/')) {
        loadDirectory('');
    }
    else {
        const parent = clean.substring(0, clean.lastIndexOf('/'));
        loadDirectory(parent);
    }
}
function isProtectedBackupPath(rel_path) {
    const clean = rel_path.trim().replace(/^\/+|\/+$/g, '');
    return (clean === 'Backup-SanDisk-1TB' ||
        clean.startsWith('Backup-SanDisk-1TB/') ||
        clean === 'SanDisk-1TB' ||
        clean.startsWith('SanDisk-1TB/'));
}
function getRootIcon(name) {
    if (name === 'Backup-SanDisk-1TB' || name === 'SanDisk-1TB')
        return '💾';
    return '📁';
}
function getQueueFolderDrivePath(item) {
    if (!item)
        return '';
    const dir = item.target_rel_dir.trim().replace(/^\/+|\/+$/g, '');
    if (item.rel_file_path && item.rel_file_path.includes('/')) {
        const relParent = item.rel_file_path.substring(0, item.rel_file_path.lastIndexOf('/'));
        const suffix = `/${relParent}`;
        if (dir.endsWith(suffix)) {
            return dir.substring(0, dir.length - suffix.length);
        }
    }
    return dir;
}
function renderBreadcrumbs() {
    const container = document.getElementById('breadcrumbs');
    const btnUp = document.getElementById('btn-nav-up');
    if (btnUp) {
        btnUp.disabled = currentRelPath === '';
    }
    if (!container)
        return;
    container.innerHTML = '';
    const rootSpan = document.createElement('span');
    rootSpan.className = `crumb ${currentRelPath === '' ? 'active' : ''}`;
    rootSpan.textContent = '~/GoogleDrive';
    rootSpan.addEventListener('click', () => {
        if (currentRelPath !== '')
            loadDirectory('');
    });
    container.appendChild(rootSpan);
    if (!currentRelPath)
        return;
    const parts = currentRelPath.split('/').filter(Boolean);
    let accum = '';
    parts.forEach((part, index) => {
        accum += (accum ? '/' : '') + part;
        const pathRef = accum;
        const isLast = index === parts.length - 1;
        const sep = document.createElement('span');
        sep.className = 'crumb-sep';
        sep.textContent = '/';
        container.appendChild(sep);
        const crumb = document.createElement('span');
        crumb.className = `crumb ${isLast ? 'active' : ''}`;
        crumb.textContent = part;
        if (!isLast) {
            crumb.addEventListener('click', () => loadDirectory(pathRef));
        }
        container.appendChild(crumb);
    });
}
function renderFilesTable() {
    const tbody = document.getElementById('files-table-body');
    if (!tbody)
        return;
    const filtered = currentItems.filter((item) => {
        if (activeFilter !== 'all' && item.sync_state !== activeFilter) {
            const hasWaitingChildren = activeFilter === 'aguardando' &&
                item.is_dir &&
                item.status_note.toLowerCase().includes('aguardando');
            if (!hasWaitingChildren) {
                return false;
            }
        }
        if (activeLocFilter !== 'all' && item.location !== activeLocFilter) {
            return false;
        }
        if (searchQuery && !item.name.toLowerCase().includes(searchQuery)) {
            return false;
        }
        return true;
    });
    if (filtered.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">Nenhum arquivo encontrado com os filtros atuais.</td></tr>';
        return;
    }
    tbody.innerHTML = '';
    filtered.forEach((item) => {
        const tr = document.createElement('tr');
        tr.className = `file-row ${selectedRelPath === item.rel_path ? 'selected' : ''}`;
        // Name & Icon
        const isProtected = isProtectedBackupPath(item.rel_path);
        const tdName = document.createElement('td');
        const nameCell = document.createElement('div');
        nameCell.className = 'file-name-cell';
        const icon = document.createElement('span');
        icon.className = 'file-icon';
        icon.textContent =
            item.name === 'Backup-SanDisk-1TB' && currentRelPath === ''
                ? getRootIcon(item.name)
                : item.is_dir
                    ? '📁'
                    : getFileIcon(item.name);
        const label = document.createElement('span');
        label.textContent = item.name;
        nameCell.appendChild(icon);
        nameCell.appendChild(label);
        tdName.appendChild(nameCell);
        // Location Badge (Nuvem / Local / Ambos)
        const tdLoc = document.createElement('td');
        const locBadge = document.createElement('span');
        locBadge.className = `badge badge-${item.location}`;
        locBadge.textContent = item.location === 'nuvem' ? '☁️ Nuvem' : item.location === 'local' ? '💻 Local' : '🔄 Ambos';
        tdLoc.appendChild(locBadge);
        // Sync State Badge & Progress
        const tdState = document.createElement('td');
        const badge = document.createElement('span');
        badge.className = `badge badge-${item.sync_state}`;
        badge.title = item.status_note;
        badge.textContent = item.sync_state === 'aguardando' ? '⏳ Aguardando'
            : item.sync_state === 'uploading' ? `⬆️ Uploading ${item.progress_percent}%`
                : '✅ Uploaded';
        tdState.appendChild(badge);
        if (item.is_dir && item.sync_state === 'uploading' && item.status_note.toLowerCase().includes('aguardando')) {
            const waitBadge = document.createElement('span');
            waitBadge.className = 'badge badge-aguardando';
            waitBadge.style.marginLeft = '4px';
            waitBadge.title = item.status_note;
            waitBadge.textContent = '⏳ Fila';
            tdState.appendChild(waitBadge);
        }
        if (item.sync_state === 'uploading') {
            const pCell = document.createElement('div');
            pCell.className = 'progress-cell mt-1';
            const pBar = document.createElement('div');
            pBar.className = 'progress-mini-bar';
            const pFill = document.createElement('div');
            pFill.className = 'progress-mini-fill';
            pFill.style.width = `${item.progress_percent}%`;
            pBar.appendChild(pFill);
            pCell.appendChild(pBar);
            tdState.appendChild(pCell);
        }
        // Size
        const tdSize = document.createElement('td');
        tdSize.textContent = item.is_dir ? '-' : formatBytes(item.size);
        // Modified
        const tdMod = document.createElement('td');
        tdMod.className = 'text-muted';
        tdMod.textContent = item.modified_str;
        // Actions
        const tdActions = document.createElement('td');
        tdActions.style.textAlign = 'right';
        const btnRename = document.createElement('button');
        btnRename.className = 'btn btn-xs btn-ghost';
        btnRename.textContent = '✏️';
        const btnDelete = document.createElement('button');
        btnDelete.className = 'btn btn-xs btn-ghost text-danger';
        btnDelete.textContent = '🗑';
        if (isProtected) {
            btnRename.disabled = true;
            btnRename.style.opacity = '0.25';
            btnRename.title = 'Pasta sincronizada pelo rclone-backup (somente leitura)';
            btnDelete.disabled = true;
            btnDelete.style.opacity = '0.25';
            btnDelete.title = 'Pasta sincronizada pelo rclone-backup (somente leitura)';
        }
        else {
            btnRename.title = 'Renomear';
            btnRename.addEventListener('click', (e) => {
                e.stopPropagation();
                openRenameModal(item);
            });
            btnDelete.title = 'Excluir';
            btnDelete.addEventListener('click', (e) => {
                e.stopPropagation();
                confirmDelete(item);
            });
        }
        tdActions.appendChild(btnRename);
        tdActions.appendChild(btnDelete);
        tr.appendChild(tdName);
        tr.appendChild(tdLoc);
        tr.appendChild(tdState);
        tr.appendChild(tdSize);
        tr.appendChild(tdMod);
        tr.appendChild(tdActions);
        // Row Click: navigate folder or select file
        tr.addEventListener('click', () => {
            selectedRelPath = item.rel_path;
            document.querySelectorAll('.file-row').forEach((r) => r.classList.remove('selected'));
            tr.classList.add('selected');
            openPreview(item);
        });
        tr.addEventListener('dblclick', () => {
            if (item.is_dir) {
                loadDirectory(item.rel_path);
            }
            else {
                invoke('open_in_system', { relPath: item.rel_path, reveal: false }).catch(() => { });
            }
        });
        tbody.appendChild(tr);
    });
}
function getFileIcon(name) {
    const ext = name.split('.').last()?.toLowerCase() || '';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].includes(ext))
        return '🖼️';
    if (['md', 'txt', 'log', 'sh', 'json', 'ts', 'js', 'rs'].includes(ext))
        return '📄';
    if (['pdf'].includes(ext))
        return '📕';
    if (['docx', 'xlsx', 'pptx'].includes(ext))
        return '📊';
    if (['zip', 'tar', 'gz'].includes(ext))
        return '📦';
    return '📄';
}
// Preview Inspector
async function openPreview(item) {
    selectedQueueFolder = null;
    document.querySelectorAll('.folder-group-card').forEach((c) => c.classList.remove('selected'));
    const pane = document.getElementById('preview-pane');
    const resizer = document.getElementById('resizer-preview');
    const title = document.getElementById('preview-title');
    const body = document.getElementById('preview-body');
    if (!pane || !title || !body)
        return;
    pane.classList.remove('hidden');
    resizer?.classList.remove('hidden');
    title.textContent = item.name;
    body.innerHTML = '<div class="text-muted text-center p-3">Carregando preview...</div>';
    try {
        const res = await invoke('preview_file', { relPath: item.rel_path });
        renderPreviewContent(res, item);
    }
    catch (e) {
        body.innerHTML = `<div class="text-danger p-3">Erro ao carregar preview: ${e}</div>`;
    }
}
function renderPreviewContent(res, item) {
    const body = document.getElementById('preview-body');
    if (!body)
        return;
    body.innerHTML = '';
    // Metadata block
    const metaBox = document.createElement('div');
    metaBox.className = 'preview-meta-list';
    metaBox.innerHTML = `
    <div class="meta-row"><span class="meta-key">Caminho:</span><span class="font-mono text-muted">${res.rel_path}</span></div>
    <div class="meta-row"><span class="meta-key">Tipo:</span><span>${res.mime_guess}</span></div>
    <div class="meta-row"><span class="meta-key">Tamanho:</span><span>${formatBytes(res.size)}</span></div>
    <div class="meta-row"><span class="meta-key">Modificado:</span><span>${res.modified_str}</span></div>
    <div class="meta-row"><span class="meta-key">Presença:</span><span class="badge badge-${item.location}">${item.location === 'nuvem' ? '☁️ Nuvem' : item.location === 'local' ? '💻 Local' : '🔄 Ambos'}</span></div>
    <div class="meta-row"><span class="meta-key">Status:</span><span class="badge badge-${item.sync_state}">${item.sync_state.toUpperCase()}</span></div>
  `;
    body.appendChild(metaBox);
    // Content Preview
    if (res.is_image && res.content.startsWith('data:image')) {
        const imgBox = document.createElement('div');
        imgBox.className = 'preview-img-box';
        const img = document.createElement('img');
        img.src = res.content;
        imgBox.appendChild(img);
        body.appendChild(imgBox);
    }
    else if (res.is_text) {
        const contentBox = document.createElement('pre');
        contentBox.className = 'preview-content-box';
        contentBox.textContent = res.content || '(arquivo vazio)';
        if (res.truncated) {
            const truncNote = document.createElement('div');
            truncNote.className = 'text-warning font-mono mt-1';
            truncNote.textContent = '[...truncado em 256 KB para performance...]';
            body.appendChild(truncNote);
        }
        body.appendChild(contentBox);
    }
    else if (!res.is_dir) {
        const binaryNotice = document.createElement('div');
        binaryNotice.className = 'text-muted text-center p-3 font-mono';
        binaryNotice.textContent = 'Arquivo binário ou não suportado para preview de texto direto.';
        body.appendChild(binaryNotice);
    }
}
function closePreview() {
    const pane = document.getElementById('preview-pane');
    const resizer = document.getElementById('resizer-preview');
    pane?.classList.add('hidden');
    resizer?.classList.add('hidden');
    selectedRelPath = null;
    selectedQueueFolder = null;
    document.querySelectorAll('.file-row').forEach((r) => r.classList.remove('selected'));
    document.querySelectorAll('.folder-group-card').forEach((c) => c.classList.remove('selected'));
}
function openFolderQueueInspector(folderName) {
    selectedQueueFolder = folderName;
    selectedRelPath = null;
    document.querySelectorAll('.file-row').forEach((r) => r.classList.remove('selected'));
    document.querySelectorAll('.folder-group-card').forEach((c) => {
        c.classList.toggle('selected', c.getAttribute('data-folder') === folderName);
    });
    const pane = document.getElementById('preview-pane');
    const resizer = document.getElementById('resizer-preview');
    pane?.classList.remove('hidden');
    resizer?.classList.remove('hidden');
    renderFolderQueueInspector();
}
function renderFolderQueueInspector() {
    if (!selectedQueueFolder || !lastDashboard)
        return;
    const title = document.getElementById('preview-title');
    const body = document.getElementById('preview-body');
    if (!title || !body)
        return;
    const folderName = selectedQueueFolder;
    const items = lastDashboard.app_queue.filter((it) => it.parent_folder === folderName);
    if (items.length === 0) {
        title.textContent = `📁 ${folderName}`;
        body.innerHTML = '<div class="text-muted text-center p-3">Nenhum item restante nesta pasta na fila.</div>';
        return;
    }
    title.textContent = `📁 Fila: ${folderName}`;
    const totalCount = items.length;
    const uploadedCount = items.filter((it) => it.state === 'uploaded').length;
    const uploadingCount = items.filter((it) => it.state === 'uploading').length;
    const waitingCount = items.filter((it) => it.state === 'aguardando').length;
    const errorCount = items.filter((it) => it.state === 'error').length;
    const totalBytes = items.reduce((acc, it) => acc + it.size, 0);
    const transferredBytes = items.reduce((acc, it) => acc + it.transferred_bytes, 0);
    const aggregatePct = totalBytes > 0 ? Math.floor((transferredBytes / totalBytes) * 100) : uploadedCount === totalCount ? 100 : 0;
    const destDir = getQueueFolderDrivePath(items[0]);
    body.innerHTML = `
    <div class="folder-queue-view">
      <div class="folder-queue-card">
        <div class="folder-queue-title-row">
          <span class="folder-queue-title">📁 ${folderName}</span>
          <button class="btn btn-xs btn-secondary" id="btn-fq-goto-dest" title="Navegar para a pasta destino no Drive">📁 Ver no Drive</button>
        </div>
        <div class="folder-queue-dest" title="Destino no Drive">Destino: ~/GoogleDrive/${destDir || '(raiz)'}</div>
        
        <div class="folder-progress-box" style="width: 100%; margin-top: 6px;">
          <div class="progress-mini-bar" style="height: 6px;"><div class="progress-mini-fill" id="fq-progress-fill" style="width: ${aggregatePct}%;"></div></div>
          <div style="display: flex; justify-content: space-between; font-size: 10px; color: var(--text-muted); margin-top: 2px;">
            <span id="fq-progress-bytes">${formatBytes(transferredBytes)} de ${formatBytes(totalBytes)}</span>
            <span id="fq-progress-pct">${aggregatePct}%</span>
          </div>
        </div>

        <div class="folder-queue-stats-grid">
          <div class="folder-stat-box"><span class="folder-stat-label">Total</span><span class="folder-stat-val" id="fq-stat-total">${totalCount} arqs</span></div>
          <div class="folder-stat-box"><span class="folder-stat-label">Concluídos</span><span class="folder-stat-val text-success" id="fq-stat-uploaded">${uploadedCount}</span></div>
          <div class="folder-stat-box"><span class="folder-stat-label">Enviando</span><span class="folder-stat-val text-info" id="fq-stat-uploading">${uploadingCount}</span></div>
          <div class="folder-stat-box"><span class="folder-stat-label">Aguardando / Erros</span><span class="folder-stat-val ${errorCount > 0 ? 'text-danger' : 'text-warning'}" id="fq-stat-wait-err">${waitingCount} / ${errorCount}</span></div>
        </div>
      </div>

      <div class="folder-queue-filter-chips" id="fq-filter-chips">
        <button class="chip-btn ${folderQueueFilter === 'all' ? 'active' : ''}" data-fqf="all">Todos (${totalCount})</button>
        <button class="chip-btn ${folderQueueFilter === 'aguardando' ? 'active' : ''}" data-fqf="aguardando">Aguardando (${waitingCount})</button>
        <button class="chip-btn ${folderQueueFilter === 'uploading' ? 'active' : ''}" data-fqf="uploading">Enviando (${uploadingCount})</button>
        <button class="chip-btn ${folderQueueFilter === 'uploaded' ? 'active' : ''}" data-fqf="uploaded">Concluídos (${uploadedCount})</button>
        ${errorCount > 0 ? `<button class="chip-btn ${folderQueueFilter === 'error' ? 'active' : ''} text-danger" data-fqf="error">Erros (${errorCount})</button>` : ''}
      </div>

      <div class="folder-queue-search-box">
        <input type="text" id="fq-search-input" placeholder="Filtrar arquivos internos..." value="${folderSearchQuery}" />
      </div>

      <div class="folder-queue-items-table" id="fq-items-container"></div>
    </div>
  `;
    document.getElementById('btn-fq-goto-dest')?.addEventListener('click', () => {
        loadDirectory(destDir).catch(() => { });
    });
    body.querySelectorAll('.chip-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
            folderQueueFilter = btn.getAttribute('data-fqf') || 'all';
            renderFolderQueueInspector();
        });
    });
    const sInput = document.getElementById('fq-search-input');
    if (sInput) {
        sInput.addEventListener('input', () => {
            folderSearchQuery = sInput.value.trim();
            renderFolderQueueItemsOnly(items);
        });
    }
    renderFolderQueueItemsOnly(items);
}
function renderFolderQueueItemsOnly(items) {
    const container = document.getElementById('fq-items-container');
    if (!container)
        return;
    const filtered = items.filter((it) => {
        if (folderQueueFilter !== 'all' && it.state !== folderQueueFilter)
            return false;
        if (folderSearchQuery) {
            const q = folderSearchQuery.toLowerCase();
            const n = (it.rel_file_path || it.target_name).toLowerCase();
            if (!n.includes(q))
                return false;
        }
        return true;
    });
    if (filtered.length === 0) {
        container.innerHTML = '<div class="text-muted text-center p-3" style="font-size: 11px;">Nenhum arquivo encontrado com os filtros atuais.</div>';
        return;
    }
    container.innerHTML = '';
    filtered.forEach((it) => {
        const card = document.createElement('div');
        card.className = `folder-queue-item-card ${it.state === 'error' ? 'has-error' : ''}`;
        const pct = it.size > 0 ? Math.floor((it.transferred_bytes / it.size) * 100) : it.state === 'uploaded' ? 100 : 0;
        const displayName = it.rel_file_path || it.target_name;
        card.innerHTML = `
      <div class="folder-queue-item-top">
        <div class="folder-queue-item-info">
          <span style="font-size: 12px;">${getFileIcon(it.target_name)}</span>
          <span class="folder-queue-item-name" title="${displayName}">${displayName}</span>
        </div>
        <div class="folder-queue-item-actions">
          <span class="text-muted" style="font-size: 10px; font-family: var(--font-mono);">${formatBytes(it.size)}</span>
          <span class="badge badge-${it.state}" style="font-size: 9px; padding: 1px 5px;">${it.state.toUpperCase()}</span>
          ${it.state === 'error' ? `<button class="btn btn-xs btn-secondary btn-retry-item" title="Tentar novamente">🔄</button>` : ''}
          ${it.state !== 'uploaded' ? `<button class="btn btn-xs btn-ghost text-danger btn-remove-item" title="Remover da fila">✕</button>` : ''}
        </div>
      </div>
      <div class="progress-mini-bar" style="height: 3px;">
        <div class="progress-mini-fill" style="width: ${pct}%;"></div>
      </div>
      ${it.error_message ? `<div class="folder-queue-item-error">⚠️ ${it.error_message}</div>` : ''}
    `;
        card.querySelector('.btn-retry-item')?.addEventListener('click', async (e) => {
            e.stopPropagation();
            try {
                await invoke('retry_upload', { id: it.id });
                showToast(`Reiniciando upload de "${it.target_name}"`, 'info');
                await refreshDashboard();
            }
            catch (err) {
                showToast(String(err), 'error');
            }
        });
        card.querySelector('.btn-remove-item')?.addEventListener('click', async (e) => {
            e.stopPropagation();
            try {
                await invoke('remove_queue_item', { id: it.id });
                showToast(`Item "${it.target_name}" removido da fila`, 'info');
                await refreshDashboard();
            }
            catch (err) {
                showToast(String(err), 'error');
            }
        });
        container.appendChild(card);
    });
}
function updateFolderQueueInspectorLive() {
    if (!selectedQueueFolder || !lastDashboard)
        return;
    const items = lastDashboard.app_queue.filter((it) => it.parent_folder === selectedQueueFolder);
    if (items.length === 0)
        return;
    const totalCount = items.length;
    const uploadedCount = items.filter((it) => it.state === 'uploaded').length;
    const uploadingCount = items.filter((it) => it.state === 'uploading').length;
    const waitingCount = items.filter((it) => it.state === 'aguardando').length;
    const errorCount = items.filter((it) => it.state === 'error').length;
    const totalBytes = items.reduce((acc, it) => acc + it.size, 0);
    const transferredBytes = items.reduce((acc, it) => acc + it.transferred_bytes, 0);
    const aggregatePct = totalBytes > 0 ? Math.floor((transferredBytes / totalBytes) * 100) : uploadedCount === totalCount ? 100 : 0;
    const pFill = document.getElementById('fq-progress-fill');
    if (pFill)
        pFill.style.width = `${aggregatePct}%`;
    const pBytes = document.getElementById('fq-progress-bytes');
    if (pBytes)
        pBytes.textContent = `${formatBytes(transferredBytes)} de ${formatBytes(totalBytes)}`;
    const pPct = document.getElementById('fq-progress-pct');
    if (pPct)
        pPct.textContent = `${aggregatePct}%`;
    const sTotal = document.getElementById('fq-stat-total');
    if (sTotal)
        sTotal.textContent = `${totalCount} arqs`;
    const sUp = document.getElementById('fq-stat-uploaded');
    if (sUp)
        sUp.textContent = String(uploadedCount);
    const sIng = document.getElementById('fq-stat-uploading');
    if (sIng)
        sIng.textContent = String(uploadingCount);
    const sWait = document.getElementById('fq-stat-wait-err');
    if (sWait) {
        sWait.textContent = `${waitingCount} / ${errorCount}`;
        sWait.className = `folder-stat-val ${errorCount > 0 ? 'text-danger' : 'text-warning'}`;
    }
    // Update items list without touching search box focus
    const searchInput = document.getElementById('fq-search-input');
    if (!searchInput || document.activeElement !== searchInput) {
        renderFolderQueueItemsOnly(items);
    }
}
function openRenameModal(item) {
    const modal = document.getElementById('modal-rename');
    const inputRel = document.getElementById('input-rename-rel');
    const inputName = document.getElementById('input-rename-name');
    if (!modal || !inputRel || !inputName)
        return;
    inputRel.value = item.rel_path;
    inputName.value = item.name;
    modal.classList.remove('hidden');
    inputName.focus();
}
async function confirmDelete(item) {
    const msg = `Tem certeza que deseja excluir "${item.name}"?`;
    if (!confirm(msg))
        return;
    try {
        await invoke('delete_entry', { relPath: item.rel_path });
        showToast(`"${item.name}" excluído`, 'info');
        if (selectedRelPath === item.rel_path)
            closePreview();
        await loadDirectory(currentRelPath);
    }
    catch (e) {
        showToast(String(e), 'error');
    }
}
// Telemetry & Dashboard Poller
async function refreshDashboard() {
    try {
        const dash = await invoke('get_transfer_dashboard');
        lastDashboard = dash;
        // Update Header Service Chips
        const mountChip = document.getElementById('service-mount-status');
        if (mountChip) {
            mountChip.className = `service-chip ${dash.mount_active ? 'active' : 'inactive'}`;
            const val = mountChip.querySelector('.chip-val');
            if (val)
                val.textContent = dash.mount_active ? 'Ativo (:5576)' : 'Inativo';
        }
        const backupChip = document.getElementById('service-backup-status');
        if (backupChip) {
            backupChip.className = `service-chip ${dash.backup_active ? 'active' : 'inactive'}`;
            const val = backupChip.querySelector('.chip-val');
            if (val)
                val.textContent = dash.backup_active ? 'Ativo (:5577)' : 'Aguardando Timer';
        }
        // VFS Cache Meter
        const elCacheText = document.getElementById('vfs-cache-text');
        const elCacheProg = document.getElementById('vfs-cache-progress');
        if (elCacheText && elCacheProg) {
            const pct = dash.vfs_disk_max > 0 ? (dash.vfs_disk_used / dash.vfs_disk_max) * 100 : 0;
            elCacheText.textContent = `${formatBytes(dash.vfs_disk_used)} / ${formatBytes(dash.vfs_disk_max)}`;
            elCacheProg.style.width = `${Math.min(pct, 100)}%`;
        }
        // Drawer Tabs Counts
        const elAppCount = document.getElementById('count-app-queue');
        const elVfsCount = document.getElementById('count-vfs-queue');
        const elBackupCount = document.getElementById('count-backup-queue');
        const elDrawerBadge = document.getElementById('drawer-badge');
        const appActive = dash.app_queue.filter((it) => it.state === 'aguardando' || it.state === 'uploading').length;
        const totalActive = appActive + dash.mount_transfers.length + dash.backup_transfers.length;
        if (elAppCount)
            elAppCount.textContent = String(dash.app_queue.length);
        if (elVfsCount)
            elVfsCount.textContent = String(dash.mount_transfers.length);
        if (elBackupCount)
            elBackupCount.textContent = String(dash.backup_transfers.length);
        if (elDrawerBadge) {
            elDrawerBadge.textContent = `${totalActive} ativas`;
            elDrawerBadge.className = `badge ${totalActive > 0 ? 'badge-uploading' : 'badge-muted'}`;
        }
        renderDrawerTransfers();
        if (selectedQueueFolder) {
            updateFolderQueueInspectorLive();
        }
        await refreshCurrentDirectorySilent();
    }
    catch {
        // Ignore transient poll errors
    }
}
function renderDrawerTransfers() {
    const pane = document.getElementById('pane-transfers-list');
    if (!pane || !lastDashboard)
        return;
    if (activeDrawerTab === 'app') {
        if (lastDashboard.app_queue.length === 0) {
            pane.innerHTML = '<div class="text-muted text-center p-3">Fila de upload do app vazia. Arraste arquivos ou pastas para enviar.</div>';
            return;
        }
        pane.innerHTML = '';
        // Group items by folder or standalone
        const folderGroups = new Map();
        const standaloneItems = [];
        lastDashboard.app_queue.forEach((it) => {
            if (it.parent_folder) {
                const group = folderGroups.get(it.parent_folder) || [];
                group.push(it);
                folderGroups.set(it.parent_folder, group);
            }
            else {
                standaloneItems.push(it);
            }
        });
        // Render Folder Groups
        folderGroups.forEach((items, folderName) => {
            const card = document.createElement('div');
            card.className = `folder-group-card ${selectedQueueFolder === folderName ? 'selected' : ''}`;
            card.setAttribute('data-folder', folderName);
            const totalCount = items.length;
            const uploadedCount = items.filter((it) => it.state === 'uploaded').length;
            const uploadingCount = items.filter((it) => it.state === 'uploading').length;
            const totalBytes = items.reduce((acc, it) => acc + it.size, 0);
            const transferredBytes = items.reduce((acc, it) => acc + it.transferred_bytes, 0);
            const isExpanded = expandedFolders.has(folderName);
            const aggregatePct = totalBytes > 0 ? Math.floor((transferredBytes / totalBytes) * 100) : uploadedCount === totalCount ? 100 : 0;
            const groupState = uploadingCount > 0 ? 'uploading'
                : uploadedCount === totalCount ? 'uploaded'
                    : 'aguardando';
            const header = document.createElement('div');
            header.className = `folder-group-header ${isExpanded ? 'expanded' : ''}`;
            header.innerHTML = `
        <div class="folder-header-left">
          <span class="folder-toggle-icon">${isExpanded ? '▼' : '▶'}</span>
          <span class="file-icon">📁</span>
          <span class="folder-group-title">${folderName}</span>
          <span class="folder-count-badge">${uploadedCount}/${totalCount} arquivos</span>
          <span class="text-muted font-mono" style="font-size: 10px;">${formatBytes(transferredBytes)} / ${formatBytes(totalBytes)}</span>
        </div>
        <div class="folder-header-right">
          <div class="folder-progress-box">
            <div class="progress-mini-bar"><div class="progress-mini-fill" style="width: ${aggregatePct}%;"></div></div>
            <span class="transfer-sub text-right">${aggregatePct}%</span>
          </div>
          <span class="badge badge-${groupState}">${groupState.toUpperCase()}</span>
          <button class="btn btn-xs btn-primary btn-inspect-folder" title="Inspecionar arquivos internos e estados">🔍 Detalhes</button>
          <button class="btn btn-xs btn-secondary btn-goto-folder" title="Navegar para destino no Google Drive">📁 Drive</button>
        </div>
      `;
            header.addEventListener('click', (e) => {
                if (e.target.closest('.btn-goto-folder') || e.target.closest('.btn-inspect-folder'))
                    return;
                openFolderQueueInspector(folderName);
                if (expandedFolders.has(folderName)) {
                    expandedFolders.delete(folderName);
                }
                else {
                    expandedFolders.add(folderName);
                }
                renderDrawerTransfers();
            });
            const btnInspect = header.querySelector('.btn-inspect-folder');
            btnInspect?.addEventListener('click', (e) => {
                e.stopPropagation();
                openFolderQueueInspector(folderName);
            });
            const btnGo = header.querySelector('.btn-goto-folder');
            btnGo?.addEventListener('click', (e) => {
                e.stopPropagation();
                const first = items[0];
                if (first) {
                    const target = getQueueFolderDrivePath(first);
                    loadDirectory(target).catch(() => { });
                }
            });
            card.appendChild(header);
            if (isExpanded) {
                const body = document.createElement('div');
                body.className = 'folder-group-body';
                items.forEach((it) => {
                    const row = document.createElement('div');
                    row.className = 'folder-file-row';
                    const pct = it.size > 0 ? Math.floor((it.transferred_bytes / it.size) * 100) : it.state === 'uploaded' ? 100 : 0;
                    const displayPath = it.rel_file_path || it.target_name;
                    row.innerHTML = `
            <div class="folder-file-info">
              <span class="file-icon" style="font-size: 12px;">${getFileIcon(it.target_name)}</span>
              <span class="folder-file-name" title="${it.source_path}">${displayPath}</span>
              <span class="text-muted" style="font-size: 10px;">(${formatBytes(it.size)})</span>
            </div>
            <div class="folder-file-progress">
              <div class="progress-mini-bar"><div class="progress-mini-fill" style="width: ${pct}%;"></div></div>
              <span class="transfer-sub text-right" style="width: 35px;">${pct}%</span>
            </div>
            <div>
              <span class="badge badge-${it.state}" style="font-size: 10px; padding: 1px 5px;">${it.state.toUpperCase()}</span>
            </div>
          `;
                    body.appendChild(row);
                });
                card.appendChild(body);
            }
            pane.appendChild(card);
        });
        // Render Standalone Items
        standaloneItems.forEach((it) => {
            const row = document.createElement('div');
            row.className = 'transfer-item';
            const pct = it.size > 0 ? Math.floor((it.transferred_bytes / it.size) * 100) : it.state === 'uploaded' ? 100 : 0;
            row.innerHTML = `
        <div class="transfer-info">
          <span class="transfer-name">${it.target_name}</span>
          <span class="transfer-sub">Destino: ~/GoogleDrive/${it.target_rel_dir || '(raiz)'} &bull; ${formatBytes(it.transferred_bytes)} / ${formatBytes(it.size)}</span>
        </div>
        <div class="transfer-progress-box">
          <div class="progress-mini-bar"><div class="progress-mini-fill" style="width: ${pct}%;"></div></div>
          <span class="transfer-sub text-right">${pct}%</span>
        </div>
        <div>
          <span class="badge badge-${it.state}">${it.state.toUpperCase()}</span>
        </div>
      `;
            pane.appendChild(row);
        });
    }
    else if (activeDrawerTab === 'vfs') {
        if (lastDashboard.mount_transfers.length === 0) {
            pane.innerHTML = '<div class="text-muted text-center p-3">Nenhum upload direto em execução no VFS do mount (:5576).</div>';
            return;
        }
        renderActiveTransferList(pane, lastDashboard.mount_transfers);
    }
    else if (activeDrawerTab === 'backup') {
        if (lastDashboard.backup_transfers.length === 0) {
            pane.innerHTML = '<div class="text-muted text-center p-3">Nenhum arquivo sendo transmitido pelo backup no momento (:5577).</div>';
            return;
        }
        renderActiveTransferList(pane, lastDashboard.backup_transfers);
    }
}
function renderActiveTransferList(container, list) {
    container.innerHTML = '';
    list.forEach((t) => {
        const isWaiting = t.source.toLowerCase().includes('aguardando');
        const row = document.createElement('div');
        row.className = 'transfer-item';
        row.innerHTML = `
      <div class="transfer-info">
        <span class="transfer-name">${t.name}</span>
        <span class="transfer-sub">${t.source} &bull; ${formatBytes(t.bytes)} / ${formatBytes(t.size)}${isWaiting ? '' : ` &bull; ${formatSpeed(t.speed_avg)}`}</span>
      </div>
      <div class="transfer-progress-box">
        <div class="progress-mini-bar"><div class="progress-mini-fill" style="width: ${t.percentage}%;"></div></div>
        <span class="transfer-sub text-right">${t.percentage}% ${t.eta ? `(ETA: ${t.eta}s)` : ''}</span>
      </div>
      <div>
        <span class="badge ${isWaiting ? 'badge-aguardando' : 'badge-uploading'}">${isWaiting ? 'AGUARDANDO' : 'UPLOADING'}</span>
      </div>
    `;
        container.appendChild(row);
    });
}
if (!Array.prototype.last) {
    Array.prototype.last = function () {
        return this.length > 0 ? this[this.length - 1] : undefined;
    };
}
export {};
