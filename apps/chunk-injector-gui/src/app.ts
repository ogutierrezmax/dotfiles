export {};

// Declaração de tipos para a API global do Tauri 2 (withGlobalTauri: true)
declare global {
  interface Window {
    __TAURI__?: {
      core: {
        invoke<T = unknown>(cmd: string, args?: Record<string, unknown>): Promise<T>;
      };
    };
  }
}

// Tipos de dados internos da aplicação
interface ChunkItem {
  id: string;
  chunk_type: 'json-key' | 'block' | 'line';
  target: string;
  target_expanded: string;
  selector: string;
  source: string;
  description: string;
  status: 'OK' | 'MISSING' | 'DRIFT' | 'TARGET_MISSING' | 'ERROR';
  expected_content: string;
  actual_content: string;
  current_file_content: string;
  projected_file_content: string;
  error_message?: string;
}

interface DiffLine {
  type: 'same' | 'add' | 'del';
  text: string;
  oldNum?: number;
  newNum?: number;
}

function computeLineDiff(oldText: string, newText: string): DiffLine[] {
  if (!oldText && !newText) return [];
  if (!oldText) {
    return newText.split('\n').map((line, idx) => ({
      type: 'add',
      text: line,
      newNum: idx + 1,
    }));
  }
  if (!newText) {
    return oldText.split('\n').map((line, idx) => ({
      type: 'del',
      text: line,
      oldNum: idx + 1,
    }));
  }

  const oldLines = oldText.split('\n');
  const newLines = newText.split('\n');

  if (oldText === newText) {
    return oldLines.map((line, idx) => ({
      type: 'same',
      text: line,
      oldNum: idx + 1,
      newNum: idx + 1,
    }));
  }

  const n = oldLines.length;
  const m = newLines.length;

  if (n * m > 4000000) {
    const result: DiffLine[] = [];
    oldLines.forEach((l, i) => result.push({ type: 'del', text: l, oldNum: i + 1 }));
    newLines.forEach((l, i) => result.push({ type: 'add', text: l, newNum: i + 1 }));
    return result;
  }

  const dp: number[][] = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < m; j++) {
      if (oldLines[i] === newLines[j]) {
        dp[i + 1][j + 1] = dp[i][j] + 1;
      } else {
        dp[i + 1][j + 1] = Math.max(dp[i + 1][j], dp[i][j + 1]);
      }
    }
  }

  const diff: DiffLine[] = [];
  let i = n;
  let j = m;

  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldLines[i - 1] === newLines[j - 1]) {
      diff.push({
        type: 'same',
        text: oldLines[i - 1],
        oldNum: i,
        newNum: j,
      });
      i--;
      j--;
    } else if (j > 0 && (i === 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      diff.push({
        type: 'add',
        text: newLines[j - 1],
        newNum: j,
      });
      j--;
    } else if (i > 0 && (j === 0 || dp[i][j - 1] < dp[i - 1][j])) {
      diff.push({
        type: 'del',
        text: oldLines[i - 1],
        oldNum: i,
      });
      i--;
    }
  }

  return diff.reverse();
}

interface ChunkListResponse {
  chunks: ChunkItem[];
  timer_active: boolean;
  timer_description: string;
}

interface SaveChunkPayload {
  original_id?: string;
  id: string;
  chunk_type: string;
  target: string;
  selector: string;
  content?: string;
  description: string;
}

class ChunkInjectorApp {
  private chunks: ChunkItem[] = [];
  private selectedChunkId: string | null = null;
  private filter: 'all' | 'issues' = 'all';
  private timerActive = false;
  private isEditingNew = false;
  private diffViewMode: 'projected' | 'split' = 'projected';

  private async invoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
    for (let i = 0; i < 25; i++) {
      const w = window as unknown as {
        __TAURI__?: { core?: { invoke<R>(cmd: string, args?: unknown): Promise<R> }; invoke?<R>(cmd: string, args?: unknown): Promise<R> };
        __TAURI_INTERNALS__?: { invoke<R>(cmd: string, args?: unknown): Promise<R> };
      };

      if (w.__TAURI__?.core?.invoke) {
        return w.__TAURI__.core.invoke<T>(cmd, args);
      }
      if (w.__TAURI__?.invoke) {
        return w.__TAURI__.invoke<T>(cmd, args);
      }
      if (w.__TAURI_INTERNALS__?.invoke) {
        return w.__TAURI_INTERNALS__.invoke<T>(cmd, args);
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    return Promise.reject(new Error('Tauri API não detectada no ambiente WebKit'));
  }

  public async init(): Promise<void> {
    this.bindEvents();
    await this.refresh();
  }

  private bindEvents(): void {
    document.getElementById('btn-refresh')?.addEventListener('click', () => this.refresh());
    document.getElementById('btn-inject-all')?.addEventListener('click', () => this.injectAll());
    document.getElementById('btn-add-chunk')?.addEventListener('click', () => this.openModal(null));
    document.getElementById('filter-all')?.addEventListener('click', () => this.setFilter('all'));
    document.getElementById('filter-issues')?.addEventListener('click', () => this.setFilter('issues'));
    document.getElementById('btn-toggle-timer')?.addEventListener('click', () => this.toggleTimer());

    // Modal
    document.getElementById('modal-close')?.addEventListener('click', () => this.closeModal());
    document.getElementById('btn-cancel-modal')?.addEventListener('click', () => this.closeModal());
    document.getElementById('chunk-form')?.addEventListener('submit', (e) => this.handleFormSubmit(e));

    // Fechar modal ao clicar no fundo (backdrop)
    document.getElementById('modal-chunk')?.addEventListener('click', (e) => {
      if (e.target === document.getElementById('modal-chunk')) {
        this.closeModal();
      }
    });

    // Fechar modal com a tecla ESC
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.closeModal();
      }
    });

    // Atualiza seletor padrão ao mudar tipo
    document.getElementById('select-type')?.addEventListener('change', (e) => {
      const type = (e.target as HTMLSelectElement).value;
      const selectorInput = document.getElementById('input-selector') as HTMLInputElement | null;
      if (selectorInput) {
        if (type === 'json-key') selectorInput.value = '.';
        else if (type === 'block') selectorInput.value = '#';
        else if (type === 'line') selectorInput.value = '-';
      }
    });
  }

  private setFilter(filter: 'all' | 'issues'): void {
    this.filter = filter;
    document.getElementById('filter-all')?.classList.toggle('active', filter === 'all');
    document.getElementById('filter-issues')?.classList.toggle('active', filter === 'issues');
    this.renderTable();
  }

  public async refresh(): Promise<void> {
    this.setLoading(true);
    try {
      const data = await this.invoke<ChunkListResponse>('list_chunks_status');
      this.chunks = data.chunks;
      this.timerActive = data.timer_active;

      if (!this.selectedChunkId && this.chunks.length > 0) {
        this.selectedChunkId = this.chunks[0].id;
      } else if (this.selectedChunkId && !this.chunks.some((c) => c.id === this.selectedChunkId)) {
        this.selectedChunkId = this.chunks.length > 0 ? this.chunks[0].id : null;
      }

      this.renderSummary();
      this.renderTable();
      this.renderDiff();
    } catch (err) {
      this.showToast(`Erro ao carregar chunks: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private renderSummary(): void {
    const total = this.chunks.length;
    const ok = this.chunks.filter((c) => c.status === 'OK').length;
    const missing = this.chunks.filter((c) => c.status === 'MISSING' || c.status === 'TARGET_MISSING').length;
    const drift = this.chunks.filter((c) => c.status === 'DRIFT').length;

    const elTotal = document.getElementById('sum-total');
    const elOk = document.getElementById('sum-ok');
    const elIssues = document.getElementById('sum-issues');
    const elTimer = document.getElementById('timer-status-badge');

    if (elTotal) elTotal.textContent = String(total);
    if (elOk) elOk.textContent = String(ok);
    if (elIssues) {
      const issues = missing + drift;
      elIssues.textContent = String(issues);
      elIssues.className = issues > 0 ? 'badge badge-danger' : 'badge badge-success';
    }

    if (elTimer) {
      elTimer.textContent = this.timerActive ? 'Timer (5m): Ativo 🟢' : 'Timer: Inativo ⚪';
      elTimer.className = this.timerActive ? 'badge badge-success' : 'badge badge-muted';
    }
  }

  private renderTable(): void {
    const tbody = document.getElementById('chunks-table-body');
    if (!tbody) return;
    tbody.innerHTML = '';

    const visibleChunks = this.chunks.filter((c) => {
      if (this.filter === 'issues') {
        return c.status !== 'OK';
      }
      return true;
    });

    if (visibleChunks.length === 0) {
      const row = document.createElement('tr');
      row.innerHTML = `<td colspan="6" class="text-center text-muted">Nenhum chunk ${this.filter === 'issues' ? 'com divergência' : 'cadastrado'}.</td>`;
      tbody.appendChild(row);
      return;
    }

    visibleChunks.forEach((chunk) => {
      const tr = document.createElement('tr');
      if (chunk.id === this.selectedChunkId) {
        tr.classList.add('selected');
      }

      tr.addEventListener('click', () => {
        this.selectedChunkId = chunk.id;
        this.renderTable();
        this.renderDiff();
      });

      let statusBadge = '';
      switch (chunk.status) {
        case 'OK':
          statusBadge = '<span class="status-badge status-ok">OK</span>';
          break;
        case 'MISSING':
        case 'TARGET_MISSING':
          statusBadge = '<span class="status-badge status-missing">AUSENTE</span>';
          break;
        case 'DRIFT':
          statusBadge = '<span class="status-badge status-drift">ALTERADO</span>';
          break;
        default:
          statusBadge = '<span class="status-badge status-error">ERRO</span>';
      }

      const actionButton =
        chunk.status === 'OK'
          ? `<button class="btn btn-sm btn-warning btn-undo-single" title="Desfazer injeção deste chunk no arquivo-alvo">↩️ Desfazer</button>`
          : `<button class="btn btn-sm btn-primary btn-inject-single" title="Injetar/Restaurar este chunk">⚡ Injetar</button>`;

      tr.innerHTML = `
        <td class="font-mono font-bold">${this.escapeHtml(chunk.id)}</td>
        <td><span class="type-tag">${this.escapeHtml(chunk.chunk_type)}</span></td>
        <td>${statusBadge}</td>
        <td class="text-secondary font-mono text-sm">${this.escapeHtml(chunk.target)}</td>
        <td class="text-sm">${this.escapeHtml(chunk.description)}</td>
        <td class="text-right actions-cell">
          ${actionButton}
          <button class="btn btn-sm btn-secondary btn-edit-single" title="Editar">✏️</button>
          <button class="btn btn-sm btn-danger btn-delete-single" title="Remover">🗑️</button>
        </td>
      `;

      tr.querySelector('.btn-inject-single')?.addEventListener('click', (e) => {
        e.stopPropagation();
        this.injectSingle(chunk.id);
      });

      tr.querySelector('.btn-undo-single')?.addEventListener('click', (e) => {
        e.stopPropagation();
        this.undoSingle(chunk.id);
      });

      tr.querySelector('.btn-edit-single')?.addEventListener('click', (e) => {
        e.stopPropagation();
        this.openModal(chunk);
      });

      tr.querySelector('.btn-delete-single')?.addEventListener('click', (e) => {
        e.stopPropagation();
        this.deleteSingle(chunk.id);
      });

      tbody.appendChild(tr);
    });
  }

  private renderDiff(): void {
    const diffContainer = document.getElementById('diff-viewer-panel');
    const headerTitle = document.getElementById('diff-chunk-title');
    const headerActions = document.getElementById('diff-header-actions');
    if (!diffContainer || !headerTitle) return;

    const chunk = this.chunks.find((c) => c.id === this.selectedChunkId);
    if (!chunk) {
      headerTitle.textContent = 'Selecione um chunk para ver o diff';
      if (headerActions) headerActions.innerHTML = '';
      diffContainer.innerHTML = '<div class="empty-state">Nenhum chunk selecionado</div>';
      return;
    }

    headerTitle.innerHTML = `
      <span class="diff-title-id">${this.escapeHtml(chunk.id)}</span>
      <span class="type-tag">${this.escapeHtml(chunk.chunk_type)}</span>
      <span class="diff-title-target">${this.escapeHtml(chunk.target)}</span>
    `;

    if (headerActions) {
      headerActions.innerHTML = `
        <button class="btn btn-sm btn-secondary" id="btn-toggle-diff-mode" title="Alternar entre projeção no arquivo e trechos isolados">
          ${this.diffViewMode === 'projected' ? '📄 Comparar Trechos' : '🔍 Preview no Arquivo'}
        </button>
        ${
          chunk.status === 'OK'
            ? `<button class="btn btn-sm btn-warning" id="btn-header-undo" title="Desfazer injeção deste chunk">↩️ Desfazer Injeção</button>`
            : `<button class="btn btn-sm btn-primary" id="btn-header-inject" title="Injetar este trecho agora">⚡ Injetar Agora</button>`
        }
      `;

      document.getElementById('btn-toggle-diff-mode')?.addEventListener('click', () => {
        this.diffViewMode = this.diffViewMode === 'projected' ? 'split' : 'projected';
        this.renderDiff();
      });

      document.getElementById('btn-header-inject')?.addEventListener('click', () => {
        this.injectSingle(chunk.id);
      });

      document.getElementById('btn-header-undo')?.addEventListener('click', () => {
        this.undoSingle(chunk.id);
      });
    }

    if (this.diffViewMode === 'split') {
      diffContainer.innerHTML = `
        <div class="diff-split">
          <div class="diff-pane">
            <div class="diff-pane-header">Esperado (Fonte: ${this.escapeHtml(chunk.source)})</div>
            <pre class="diff-code diff-expected"><code>${this.escapeHtml(chunk.expected_content || '(vazio)')}</code></pre>
          </div>
          <div class="diff-pane">
            <div class="diff-pane-header">Atual no Arquivo-Alvo (${this.escapeHtml(chunk.target)})</div>
            <pre class="diff-code diff-actual ${chunk.status !== 'OK' ? 'diff-mismatch' : ''}"><code>${this.escapeHtml(chunk.actual_content || (chunk.status === 'TARGET_MISSING' ? '(arquivo não existe)' : '(não encontrado)'))}</code></pre>
          </div>
        </div>
      `;
      return;
    }

    // Modo projetado: diff linha por linha entre o arquivo atual e o projetado pós-injeção
    const currentText = chunk.current_file_content || '';
    const projectedText = chunk.projected_file_content || '';
    const diffLines = computeLineDiff(currentText, projectedText);

    const adds = diffLines.filter((l) => l.type === 'add').length;
    const dels = diffLines.filter((l) => l.type === 'del').length;

    let bannerHtml = '';
    if (chunk.status === 'OK') {
      bannerHtml = `
        <div class="diff-banner banner-ok">
          <span class="banner-icon">✅</span>
          <span class="banner-text"><strong>Sincronizado:</strong> O trecho já está aplicado e íntegro no arquivo-alvo. O preview abaixo reflete o estado atual salvo.</span>
          <button class="btn btn-sm btn-warning" id="btn-banner-undo" style="margin-left: auto;">↩️ Desfazer Injeção</button>
        </div>
      `;
    } else if (chunk.status === 'TARGET_MISSING') {
      bannerHtml = `
        <div class="diff-banner banner-warning">
          <span class="banner-icon">📁</span>
          <span class="banner-text"><strong>Arquivo novo:</strong> O arquivo <code>${this.escapeHtml(chunk.target)}</code> ainda não existe. Ao injetar, será criado com as <strong>+${adds}</strong> linhas verdes abaixo.</span>
        </div>
      `;
    } else if (chunk.status === 'MISSING') {
      bannerHtml = `
        <div class="diff-banner banner-missing">
          <span class="banner-icon">⚡</span>
          <span class="banner-text"><strong>Preview pós-injeção:</strong> O trecho em <span class="tag-add">+ verde (${adds} linha${adds === 1 ? '' : 's'})</span> será injetado no arquivo atual. Clique em <strong>Injetar Agora</strong> para aplicar.</span>
        </div>
      `;
    } else if (chunk.status === 'DRIFT') {
      bannerHtml = `
        <div class="diff-banner banner-drift">
          <span class="banner-icon">⚠️</span>
          <span class="banner-text"><strong>Divergência detectada:</strong> O trecho em <span class="tag-del">- vermelho (${dels})</span> será substituído pelo trecho em <span class="tag-add">+ verde (${adds})</span>.</span>
        </div>
      `;
    } else {
      bannerHtml = `
        <div class="diff-banner banner-error">
          <span class="banner-icon">❌</span>
          <span class="banner-text"><strong>Erro no chunk:</strong> ${this.escapeHtml(chunk.error_message || 'Falha ao inspecionar chunk')}</span>
        </div>
      `;
    }

    const linesHtml = diffLines
      .map((line) => {
        const oldNumStr = line.oldNum !== undefined ? String(line.oldNum) : '';
        const newNumStr = line.newNum !== undefined ? String(line.newNum) : '';
        let sign = '&nbsp;';
        let rowClass = 'diff-row diff-row-same';

        if (line.type === 'add') {
          sign = '+';
          rowClass = 'diff-row diff-row-add';
        } else if (line.type === 'del') {
          sign = '-';
          rowClass = 'diff-row diff-row-del';
        }

        const safeText = this.escapeHtml(line.text) || '&nbsp;';

        return `
          <div class="${rowClass}">
            <span class="gutter-num gutter-old">${oldNumStr}</span>
            <span class="gutter-num gutter-new">${newNumStr}</span>
            <span class="gutter-sign">${sign}</span>
            <span class="row-code"><code>${safeText}</code></span>
          </div>
        `;
      })
      .join('');

    diffContainer.innerHTML = `
      <div class="diff-projected-wrapper">
        ${bannerHtml}
        <div class="diff-code-viewport">
          <div class="diff-table">${linesHtml}</div>
        </div>
      </div>
    `;

    document.getElementById('btn-banner-undo')?.addEventListener('click', () => {
      this.undoSingle(chunk.id);
    });
  }

  private async injectSingle(id: string): Promise<void> {
    this.setLoading(true);
    try {
      await this.invoke('inject_chunk', { id });
      this.showToast(`Chunk "${id}" injetado com sucesso!`, 'success', {
        label: '↩️ Desfazer',
        onClick: () => this.undoSingle(id),
      });
      await this.refresh();
    } catch (err) {
      this.showToast(`Erro ao injetar chunk: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private async undoSingle(id: string): Promise<void> {
    this.setLoading(true);
    try {
      await this.invoke('undo_chunk', { id });
      this.showToast(`Injeção de "${id}" desfeita com sucesso!`, 'info');
      await this.refresh();
    } catch (err) {
      this.showToast(`Erro ao desfazer injeção: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private async injectAll(): Promise<void> {
    this.setLoading(true);
    try {
      await this.invoke('inject_all_chunks');
      this.showToast('Todos os chunks foram processados e injetados!', 'success');
      await this.refresh();
    } catch (err) {
      this.showToast(`Erro ao injetar chunks: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private async deleteSingle(id: string): Promise<void> {
    if (!confirm(`Tem certeza que deseja remover o chunk "${id}" da lista de monitoramento?`)) {
      return;
    }
    this.setLoading(true);
    try {
      await this.invoke('delete_chunk_entry', { id });
      this.showToast(`Chunk "${id}" removido da configuração.`, 'info');
      await this.refresh();
    } catch (err) {
      this.showToast(`Erro ao remover: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private async toggleTimer(): Promise<void> {
    this.setLoading(true);
    try {
      const res = await this.invoke<{ active: boolean }>('toggle_systemd_timer');
      this.timerActive = res.active;
      this.showToast(this.timerActive ? 'Timer systemd ativado!' : 'Timer systemd desativado.', 'info');
      this.renderSummary();
    } catch (err) {
      this.showToast(`Erro ao alternar timer: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private openModal(chunk: ChunkItem | null): void {
    const modal = document.getElementById('modal-chunk');
    const title = document.getElementById('modal-title');
    const form = document.getElementById('chunk-form') as HTMLFormElement;
    if (!modal || !title || !form) return;

    this.isEditingNew = chunk === null;
    form.reset();

    if (chunk) {
      title.textContent = `Editar Chunk: ${chunk.id}`;
      (document.getElementById('input-original-id') as HTMLInputElement).value = chunk.id;
      (document.getElementById('input-id') as HTMLInputElement).value = chunk.id;
      (document.getElementById('select-type') as HTMLSelectElement).value = chunk.chunk_type;
      (document.getElementById('input-target') as HTMLInputElement).value = chunk.target;
      (document.getElementById('input-selector') as HTMLInputElement).value = chunk.selector;
      (document.getElementById('input-content') as HTMLTextAreaElement).value = chunk.expected_content || '';
      (document.getElementById('input-description') as HTMLInputElement).value = chunk.description;
    } else {
      title.textContent = 'Adicionar Novo Chunk';
      (document.getElementById('input-original-id') as HTMLInputElement).value = '';
      (document.getElementById('input-id') as HTMLInputElement).value = '';
      (document.getElementById('select-type') as HTMLSelectElement).value = 'json-key';
      (document.getElementById('input-target') as HTMLInputElement).value = '';
      (document.getElementById('input-selector') as HTMLInputElement).value = '.';
      (document.getElementById('input-content') as HTMLTextAreaElement).value = '';
      (document.getElementById('input-description') as HTMLInputElement).value = '';
    }

    modal.classList.remove('hidden');
    setTimeout(() => {
      (document.getElementById('input-id') as HTMLInputElement | null)?.focus();
    }, 50);
  }

  private closeModal(): void {
    document.getElementById('modal-chunk')?.classList.add('hidden');
  }

  private async handleFormSubmit(e: Event): Promise<void> {
    e.preventDefault();
    const originalId = (document.getElementById('input-original-id') as HTMLInputElement).value;
    const id = (document.getElementById('input-id') as HTMLInputElement).value.trim();
    const chunkType = (document.getElementById('select-type') as HTMLSelectElement).value;
    const target = (document.getElementById('input-target') as HTMLInputElement).value.trim();
    const selector = (document.getElementById('input-selector') as HTMLInputElement).value.trim();
    const content = (document.getElementById('input-content') as HTMLTextAreaElement).value;
    const description = (document.getElementById('input-description') as HTMLInputElement).value.trim();

    if (!id || !target || !content) {
      this.showToast('Preencha os campos obrigatórios (ID, Alvo, Conteúdo do Trecho).', 'error');
      return;
    }

    const payload: SaveChunkPayload = {
      original_id: originalId || undefined,
      id,
      chunk_type: chunkType,
      target,
      selector: selector || (chunkType === 'json-key' ? '.' : '#'),
      content,
      description: description || id
    };

    this.setLoading(true);
    try {
      await this.invoke('save_chunk_entry', { payload });
      this.showToast(`Chunk "${id}" salvo com sucesso!`, 'success');
      this.closeModal();
      this.selectedChunkId = id;
      await this.refresh();
    } catch (err) {
      this.showToast(`Erro ao salvar: ${(err as Error).message}`, 'error');
    } finally {
      this.setLoading(false);
    }
  }

  private setLoading(loading: boolean): void {
    const spinner = document.getElementById('loading-indicator');
    if (spinner) {
      spinner.classList.toggle('hidden', !loading);
    }
  }

  private showToast(
    message: string,
    type: 'success' | 'error' | 'info' = 'info',
    action?: { label: string; onClick: () => void }
  ): void {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const textSpan = document.createElement('span');
    textSpan.className = 'toast-message';
    textSpan.textContent = message;
    toast.appendChild(textSpan);

    if (action) {
      const actionBtn = document.createElement('button');
      actionBtn.className = 'btn btn-sm btn-warning toast-action-btn';
      actionBtn.textContent = action.label;
      actionBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        toast.remove();
        action.onClick();
      });
      toast.appendChild(actionBtn);
    }

    container.appendChild(toast);
    const duration = action ? 7000 : 4000;
    setTimeout(() => {
      toast.classList.add('fade-out');
      setTimeout(() => toast.remove(), 300);
    }, duration);
  }

  private escapeHtml(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

function startApp(): void {
  const app = new ChunkInjectorApp();
  app.init().catch((err) => {
    console.error('Falha ao inicializar ChunkInjectorApp:', err);
  });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', startApp);
} else {
  startApp();
}
