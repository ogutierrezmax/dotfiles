#Requires -Version 5.1
# === install-dotfiles.ps1 ===
# Instala os dotfiles Windows a partir de config/dotfile-names-windows.list —
# INDEPENDENTE do fluxo Linux (scripts/install-dotfiles.sh + config/dotfile-names.list);
# nenhuma lista/script .sh é lido ou modificado por aqui.
#
# Modos de execução:
#   (padrão)     aplica (confirma antes; use -Yes para não interativo)
#   -Status      diagnóstico read-only: estado de cada entrada
#   -Remove      remove APENAS links que apontam para este repositório
#
# Garantias:
#   - arquivo/dir real existente é movido para <repo>/.bkp com slug datado
#     (nunca é apagado nem sobrescrito sem backup);
#   - link errado/quebrado é religado; conteúdo real DIFERENTE nunca é tocado
#     em -Remove;
#   - fallback sem privilégio: symlink → junction (dirs) → cópia (files);
#     symlinks reais voltam a funcionar após sign-out/sign-in com Developer Mode;
#   - idempotente: rodar N vezes leva ao mesmo estado.
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$Status,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'dotfiles-lib.ps1')

function Get-WindowsDotfileEntries {
    $listFile = Join-Path (Get-DotfilesRepoRoot) 'config\dotfile-names-windows.list'
    if (-not (Test-Path -LiteralPath $listFile)) {
        throw "config/dotfile-names-windows.list não encontrado: $listFile"
    }
    foreach ($raw in Get-Content -LiteralPath $listFile) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $line = ($line -split '#', 2)[0].Trim()
        $parts = $line -split '\|', 2
        if ($parts.Count -ne 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) {
            Write-Warning "linha inválida ignorada: $raw"
            continue
        }
        [pscustomobject]@{
            Source = Join-Path (Get-DotfilesDataDir) $parts[0].Trim()
            Rel    = $parts[0].Trim()
            Dest   = Expand-DotfilesDest $parts[1].Trim()
        }
    }
}

# Estados: not_installed | installed | wrong_target | blocking_file | unavailable
function Get-WindowsDotfileState([string]$Src, [string]$Dest) {
    if (-not (Test-Path -LiteralPath $Src)) { return 'unavailable' }
    $target = Get-DotfilesLinkTarget $Dest
    if ($null -ne $target) {
        $same = (ConvertTo-DotfilesNormPath $target) -eq (ConvertTo-DotfilesNormPath $Src)
        if ($same) { return 'installed' }
        return 'wrong_target'
    }
    if (-not (Test-Path -LiteralPath $Dest)) { return 'not_installed' }
    # Conteúdo idêntico à fonte = instalado em modo cópia (sem isso, re-rodar
    # daria backup + cópia nova toda vez).
    $srcItem = Get-Item -LiteralPath $Src -Force
    $destItem = Get-Item -LiteralPath $Dest -Force
    if (-not $srcItem.PSIsContainer -and -not $destItem.PSIsContainer) {
        if ((Get-FileHash -LiteralPath $Src -Algorithm SHA256).Hash -eq
            (Get-FileHash -LiteralPath $Dest -Algorithm SHA256).Hash) {
            return 'installed'
        }
    }
    return 'blocking_file'
}

function Invoke-WindowsDotfilesRemove([object]$Entries) {
    $removed = 0
    foreach ($e in $Entries) {
        $state = Get-WindowsDotfileState $e.Source $e.Dest
        switch ($state) {
            'installed' {
                Write-Host "Removendo link: $($e.Dest)"
                Remove-DotfilesLink $e.Dest
                $removed++
            }
            'wrong_target' {
                Write-Host "Aviso: $($e.Dest) é link para outro lugar — não tocado."
            }
            default { }
        }
    }
    Write-Host "Removidos: $removed link(s) apontando para este repositório."
}

function Invoke-WindowsDotfilesApply([object]$Entries, [bool]$Confirm) {
    $toInstall = @()
    $blocking = @()
    $copyUpgrades = @()
    foreach ($e in $Entries) {
        $state = Get-WindowsDotfileState $e.Source $e.Dest
        switch ($state) {
            'unavailable' { Write-Warning "não existe em data/, pulando: $($e.Rel)" }
            'installed' {
                Write-Host "ok: $($e.Rel) → $($e.Dest)"
                # Cópia idêntica (instalada sem symlink) pode ser promovida a
                # symlink quando o privilégio estiver disponível de novo.
                if (-not (Test-DotfilesIsLink $e.Dest) -and
                    -not (Get-Item -LiteralPath $e.Source -Force).PSIsContainer) {
                    $copyUpgrades += $e
                }
            }
            'wrong_target' {
                Write-Host "Relink: $($e.Dest) (apontava para outro lugar)"
                $toInstall += $e
            }
            'blocking_file' { $blocking += $e; $toInstall += $e }
            'not_installed' { $toInstall += $e }
        }
    }
    if ($copyUpgrades.Count -gt 0 -and -not (Test-DotfilesSymlinkCapability)) {
        $copyUpgrades = @()
    }

    if ($blocking.Count -gt 0) {
        Write-Host ""
        Write-Host "Os seguintes arquivos/dirs REAIS serão movidos para backup (.bkp) e substituídos por links:"
        foreach ($e in $blocking) { Write-Host "  $($e.Dest)" }
        Write-Host ""
    }
    if ($copyUpgrades.Count -gt 0) {
        Write-Host "Symlinks disponíveis: cópias serão promovidas a symlink (com backup):"
        foreach ($e in $copyUpgrades) { Write-Host "  $($e.Dest)" }
        Write-Host ""
    }

    if ($Confirm) {
        $resposta = Read-Host 'Deseja continuar? (s/n)'
        if ($resposta -notmatch '^[sS]$') {
            Write-Host 'Instalação cancelada.'
            return
        }
        Write-Host ''
    }

    $nLink = 0; $nCopy = 0; $nJunction = 0
    foreach ($e in $toInstall) {
        $state = Get-WindowsDotfileState $e.Source $e.Dest
        if ($state -eq 'blocking_file') {
            $null = Backup-DotfilesDest $e.Dest
        } elseif ($state -eq 'wrong_target') {
            Remove-DotfilesLink $e.Dest
        }
        Write-Host "Criando link para $($e.Rel) → $($e.Dest)"
        try {
            $kind = New-DotfilesLink $e.Dest $e.Source
        } catch {
            Write-Host "  ERRO: não foi possível criar $($e.Dest): $($_.Exception.Message)"
            continue
        }
        switch ($kind) {
            'symlink' { $nLink++ }
            'junction' { $nJunction++ }
            'copy' {
                $nCopy++
                Write-Host "  AVISO: modo CÓPIA (symlink indisponível sem admin): $($e.Rel)"
                Write-Host "         rode o instalador novamente após 'git pull' para ressincronizar."
            }
        }
    }

    foreach ($e in $copyUpgrades) {
        Write-Host "Promovendo cópia → symlink: $($e.Dest)"
        try {
            $null = Backup-DotfilesDest $e.Dest
            $null = New-DotfilesLink $e.Dest $e.Source
        } catch {
            Write-Host "  ERRO: não foi possível promover $($e.Dest): $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host "Instalados: $($toInstall.Count) — symlinks: $nLink, junctions: $nJunction, cópias: $nCopy, promovidos: $($copyUpgrades.Count)"

    $bridge = Join-Path $PSScriptRoot 'install-agent-skills-bridge.ps1'
    if (Test-Path -LiteralPath $bridge) {
        Write-Host ''
        Write-Host 'Bridge de skills de IA → acervo central (~/.agents/skills)'
        & $bridge
    }
    Write-Host ''
    Write-Host 'Configuração concluída!'
}

function Show-WindowsDotfilesStatus([object]$Entries) {
    Write-Host ('{0,-14} {1} → {2}' -f 'ESTADO', 'FONTE (data/)', 'DESTINO')
    Write-Host ('-' * 100)
    $counts = @{}
    foreach ($e in $Entries) {
        $state = Get-WindowsDotfileState $e.Source $e.Dest
        $counts[$state] = 1 + [int]$counts[$state]
        Write-Host ('{0,-14} {1} → {2}' -f $state, $e.Rel, $e.Dest)
    }
    Write-Host ''
    Write-Host ('Resumo: ' + (($counts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '))
}

$entries = @(Get-WindowsDotfileEntries)

if ($Status) {
    Show-WindowsDotfilesStatus $entries
} elseif ($Remove) {
    Invoke-WindowsDotfilesRemove $entries
} else {
    Invoke-WindowsDotfilesApply $entries (-not $Yes)
}
