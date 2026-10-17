# === dotfiles-lib.ps1 ===
# Biblioteca compartilhada pelos scripts Windows (PowerShell 5.1+).
# Espelha a semântica de scripts/dotfiles-lib.sh: fonte única em data/, backups
# datados em <repo>/.bkp, estados de link (installed/wrong_target/blocking_file).
# Uso: . "$PSScriptRoot\dotfiles-lib.ps1"

$script:DotfilesLibDir = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $PSScriptRoot
}
$script:DotfilesRepoRoot = (Resolve-Path -LiteralPath (Join-Path $script:DotfilesLibDir '..')).Path

function Get-DotfilesRepoRoot { $script:DotfilesRepoRoot }
function Get-DotfilesDataDir { Join-Path $script:DotfilesRepoRoot 'data' }
function Get-DotfilesBackupDir { Join-Path $script:DotfilesRepoRoot '.bkp' }

# Expande o destino de config/dotfile-names-windows.list: ~ → USERPROFILE,
# %VAR% → variável de ambiente.
function Expand-DotfilesDest([string]$Dest) {
    $d = [Environment]::ExpandEnvironmentVariables($Dest)
    if ($d -eq '~') { return $env:USERPROFILE }
    if ($d.StartsWith('~/') -or $d.StartsWith('~\')) {
        return Join-Path $env:USERPROFILE $d.Substring(2)
    }
    return $d
}

# Normaliza um caminho para comparação semântica (full path, sem barra final).
# Comparação de caminhos no Windows é case-insensitive por padrão (-eq).
function ConvertTo-DotfilesNormPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

# Resolve o path real de um caminho, expandindo symlinks/junctions componente a
# componente (equivalente ao realpath do Linux; .NET Framework não tem realpath).
function Get-DotfilesRealPath([string]$Path) {
    $acc = [System.IO.Path]::GetFullPath($Path)
    $parts = $acc -split '\\'
    $acc = $parts[0]
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $acc = Join-Path $acc $parts[$i]
        $t = Get-DotfilesLinkTarget $acc
        if ($null -ne $t) { $acc = $t }
    }
    return $acc
}

# Alvo de um symlink/junction (string) ou $null se o caminho não é link.
# Aceita link quebrado (Test-Path retornaria $false para ele).
function Get-DotfilesLinkTarget([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or -not $item.LinkType) { return $null }
    $t = @($item.Target)[0]
    if (-not $t) { return $null }
    return [System.IO.Path]::GetFullPath($t)
}

function Test-DotfilesIsLink([string]$Path) {
    return $null -ne (Get-DotfilesLinkTarget $Path)
}

# O link em $Dest aponta (direta ou indiretamente) para $Src?
function Test-DotfilesLinkTo([string]$Dest, [string]$Src) {
    $t = Get-DotfilesLinkTarget $Dest
    if ($null -eq $t) { return $false }
    return (ConvertTo-DotfilesNormPath $t) -eq (ConvertTo-DotfilesNormPath $Src)
}

# Slug de backup DD-MM-AAAA_HH-MM_<basename> (o ":" do formato bash é ilegal
# em nomes de arquivo no Windows), com sufixo _N em caso de colisão.
function Get-DotfilesBackupSlug([string]$BaseName) {
    $bkpDir = Get-DotfilesBackupDir
    New-Item -ItemType Directory -Force -Path $bkpDir | Out-Null
    $stamp = Get-Date -Format 'dd-MM-yyyy_HH-MM'
    $slug = "${stamp}_${BaseName}"
    $n = 0
    while (Test-Path -LiteralPath (Join-Path $bkpDir $slug)) {
        $n++
        $slug = "${stamp}_${BaseName}_${n}"
    }
    return (Join-Path $bkpDir $slug)
}

# Move um destino REAL (não-link) para .bkp com slug datado. Nunca apaga.
function Backup-DotfilesDest([string]$Dest) {
    if (-not (Test-Path -LiteralPath $Dest)) { throw "não existe: $Dest" }
    $item = Get-Item -LiteralPath $Dest -Force
    if ($item.LinkType) { throw "$Dest já é link (não precisa de backup)" }
    $target = Get-DotfilesBackupSlug $item.Name
    Write-Host "  Backup: $Dest → $target"
    Move-Item -LiteralPath $Dest -Destination $target
    return $target
}

# Cria $Dest → $Src com fallback sem privilégio (esta máquina exige admin para
# symlink): dir → junction; file → cópia (single-use; avisar o chamador).
# Retorna 'symlink' | 'junction' | 'copy'.
function New-DotfilesLink([string]$Dest, [string]$Src) {
    $parent = Split-Path -Parent $Dest
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $isDir = (Get-Item -LiteralPath $Src -Force).PSIsContainer
    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Src -ErrorAction Stop | Out-Null
        return 'symlink'
    } catch {
        if ($isDir) {
            New-Item -ItemType Junction -Path $Dest -Target $Src -ErrorAction Stop | Out-Null
            return 'junction'
        }
        Copy-Item -LiteralPath $Src -Destination $Dest
        return 'copy'
    }
}

# Remove SÓ o reparse point (symlink/junction), sem jamais tocar no alvo.
# Remove-Item -Recurse em junction pode apagar o conteúdo do alvo; .Delete() não.
function Remove-DotfilesLink([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.LinkType) { throw "$Path não é link" }
    $item.Delete()
}

# Dois diretórios são conteúdo-a-conteúdo idênticos? (rel path + SHA256 por arquivo)
function Test-DotfilesDirsIdentical([string]$A, [string]$B) {
    $filesA = @(Get-ChildItem -LiteralPath $A -Recurse -Force -File)
    $filesB = @(Get-ChildItem -LiteralPath $B -Recurse -Force -File)
    if ($filesA.Count -ne $filesB.Count) { return $false }
    $map = @{}
    foreach ($f in $filesA) {
        $map[$f.FullName.Substring($A.Length)] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }
    foreach ($f in $filesB) {
        $rel = $f.FullName.Substring($B.Length)
        if (-not $map.ContainsKey($rel)) { return $false }
        if ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne $map[$rel]) { return $false }
    }
    return $true
}

# O sistema permite criar symlinks sem admin agora? (Developer Mode + re-login;
# probe descartável em %TEMP%). Usado pelo instalador para promover CóPIAS
# antigas a symlinks reais quando o privilégio volta a existir.
function Test-DotfilesSymlinkCapability {
    $probe = Join-Path $env:TEMP ("dotfiles-linkprobe-" + [guid]::NewGuid().ToString('N'))
    $probeTarget = "$probe.target"
    try {
        Set-Content -LiteralPath $probeTarget -Value 'probe' -NoNewline
        New-Item -ItemType SymbolicLink -Path $probe -Target $probeTarget -ErrorAction Stop | Out-Null
        (Get-Item -LiteralPath $probe).Delete()
        return $true
    } catch {
        if (Test-Path -LiteralPath $probe) {
            try { (Get-Item -LiteralPath $probe).Delete() } catch { }
        }
        return $false
    } finally {
        Remove-Item -LiteralPath $probeTarget -Force -ErrorAction SilentlyContinue
    }
}
