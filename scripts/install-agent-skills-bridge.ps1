#Requires -Version 5.1
# === install-agent-skills-bridge.ps1 ===
# Converge os diretórios de skills de cada ferramenta de IA para o acervo central
# versionado ~/.agents/skills (o próprio data/.agents/skills via link ~/.agents,
# criado por install-dotfiles.ps1). Port Windows de install-agent-skills-bridge.sh
# — MESMO config (config/agent-skills-bridge.list) e mesma semântica.
#
# Configuração: config/agent-skills-bridge.list
#   formato: <ferramenta>|<spec>  onde spec é:
#     "*"           → todas as "leaf skills" de topo (dir com SKILL.md direto)
#     "**"          → TODAS as skills em qualquer profundidade, achatadas por
#                     basename (o dir da skill vira o nome da skill)
#     "@manifest"   → gera/atualiza o manifest (Antigravity: ~/.gemini/config/skills.json)
#     "<nome>"      → skill leaf, ex.: context7-mcp
#     "<bundle>/<nome>" → sub-skill dentro de um bundle
#
# Modos de execução:
#   (padrão)    aplica as mudanças (bootstrap e re-convergência)
#   -DryRun     imprime o que faria, sem escrever nada em $HOME
#   -Doctor     diagnóstico read-only: o que cada tool enxerga + drift
#               (exit 1 se houver drift)
#
# SECURITY NOTE (mesmos guardrails do script bash):
#  - Declarativo + idempotente: o estado desejado vem do acervo + do config;
#    rodar N vezes leva ao mesmo estado (nada duplica, nada quebra).
#  - Só REMOVE/REESCREVE um destino nas seguintes condições:
#      * link GERENCIADO (aponta para o acervo) cujo alvo deixou de existir
#        (órfão) — removido para não confundir a ferramenta;
#      * diretório REAL byte-a-byte idêntico ao acervo — movido para .bkp antes
#        do link (nada é apagado sem backup);
#      * link que É o próprio acervo (alias) — normalizado em links por-skill
#        (remove-se só o link; a fonte, nunca).
#  - Diretório REAL diferente do acervo → alerta e PULA (nunca destrói trabalho).
#  - Manifest (skills.json) só é sobrescrito com backup datado em .bkp/.
#  - Nunca usa Remove-Item -Recurse em links; nunca toca em skills fora do
#    escopo configurado (ex.: pinokio no Claude, skills da Google Cloud).
#  - Fallback Windows: symlink sem privilégio → junction (transparente p/ tools).
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Doctor
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'dotfiles-lib.ps1')

$script:Center = Join-Path $env:USERPROFILE '.agents\skills'
$script:ConfigFile = Join-Path (Get-DotfilesRepoRoot) 'config\agent-skills-bridge.list'

# Mapa ferramenta → diretório(s) de skills em $USERPROFILE. Mesmos caminhos do
# bash: as ferramentas usam o home do usuário nos dois SOs.
$script:ToolDirs = @{
    claude      = @(Join-Path $env:USERPROFILE '.claude\skills')
    devin       = @(Join-Path $env:USERPROFILE '.config\devin\skills')
    antigravity = @(
        (Join-Path $env:USERPROFILE '.agent\skills'),
        (Join-Path $env:USERPROFILE '.gemini\antigravity\skills'),
        (Join-Path $env:USERPROFILE '.gemini\config\skills')
    )
    copilot     = @(Join-Path $env:USERPROFILE '.copilot\skills')
    cursor      = @(Join-Path $env:USERPROFILE '.cursor\skills')
    gemini      = @(Join-Path $env:USERPROFILE '.gemini\skills')
}

$script:ToolManifest = @{
    antigravity = Join-Path $env:USERPROFILE '.gemini\config\skills.json'
}

# Profundidade máxima (a partir do acervo) em que um SKILL.md conta como skill:
# <leaf>/SKILL.md = 1 e <bundle>/<skill>/SKILL.md = 2 (find -maxdepth 3 no bash).
$script:BridgeMaxDepth = 2

$script:BridgeMode = if ($Doctor) { 'doctor' } elseif ($DryRun) { 'dry-run' } else { 'apply' }
$script:BridgeNOk = 0
$script:BridgeNRelink = 0
$script:BridgeNConvert = 0
$script:BridgeNSkipDiff = 0
$script:BridgeNOrphan = 0
$script:BridgeNCreated = 0
$script:BridgeNAlias = 0
$script:BridgeNManifest = 0
$script:BridgeNCollision = 0
$script:BridgeNNameWarn = 0
$script:BridgeNError = 0
$script:BridgeDrift = 0
$script:BridgeRows = New-Object System.Collections.ArrayList
$script:BridgeWarnings = New-Object System.Collections.ArrayList
$script:BridgeSkills = @{}
$script:BridgeSkillNames = @()
$script:BridgeCollisions = @()

function bridge_warn([string]$Message) {
    $null = $script:BridgeWarnings.Add($Message)
    if ($script:BridgeMode -ne 'doctor') {
        Write-Host "  AVISO: $Message"
    }
}

function bridge_drift { $script:BridgeDrift++ }
function bridge_is_apply { $script:BridgeMode -eq 'apply' }

# Rótulo honesto por modo: o texto diz o que JÁ aconteceu (apply) ou o que
# aconteceria (dry-run/doctor).
function Get-BridgeLabel([string]$Action) {
    switch ($script:BridgeMode) {
        'apply' { return $Action }
        'dry-run' { return "[dry-run] $Action" }
        'doctor' { return "[doctor] $Action pendente" }
    }
}

# Nome de skill aceito sem risco pelas ferramentas: começa por [a-z0-9], corpo
# [-._]. Avisamos, mas nunca renomeamos (SKILL.md é fonte versionada).
function Test-BridgeNameOk([string]$Name) {
    return $Name -match '^[a-z0-9][a-z0-9._-]*$'
}

function Get-BridgeCenterReal { Get-DotfilesRealPath $script:Center }

# O caminho $Path (alvo de link) aponta para dentro do acervo (caminho lógico
# ~/.agents/... OU path real do repo)? Ambos os formatos são gerenciados.
function Test-BridgeInsideCenter([string]$Path) {
    $norm = ConvertTo-DotfilesNormPath $Path
    $center = ConvertTo-DotfilesNormPath $script:Center
    $centerReal = ConvertTo-DotfilesNormPath (Get-BridgeCenterReal)
    return $norm -eq $center -or $norm.StartsWith("$center\") -or
        $norm -eq $centerReal -or $norm.StartsWith("$centerReal\")
}

# ---------------------------------------------------------------------------
# Descoberta do acervo (roda UMA vez; determinístico → idempotente e diffável)
# Colisão de basename → as AMBAS ficam de fora (nunca escolhe por conta).
# ---------------------------------------------------------------------------
function Invoke-BridgeDiscover {
    $script:BridgeSkills = @{}
    $script:BridgeSkillNames = @()
    $script:BridgeCollisions = @()
    $center = ConvertTo-DotfilesNormPath $script:Center
    $found = Get-ChildItem -LiteralPath $script:Center -Recurse -Depth $script:BridgeMaxDepth `
        -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue
    $seen = @{}
    $collided = @{}
    foreach ($f in ($found | Sort-Object FullName)) {
        $dir = $f.DirectoryName
        $name = Split-Path $dir -Leaf
        $rel = $dir.Substring($center.Length).TrimStart('\')
        if ($seen.ContainsKey($name)) {
            $null = $script:BridgeCollisions.Add([pscustomobject]@{
                Name = $name; Rel1 = $seen[$name]; Rel2 = $rel
            })
            $collided[$name] = $true
            continue
        }
        $seen[$name] = $rel
    }
    $script:BridgeSkills = $seen
    $script:BridgeSkillNames = @($seen.Keys | Where-Object { -not $collided.ContainsKey($_) } | Sort-Object)
    $script:BridgeNCollision = $script:BridgeCollisions.Count
}

# Leaves de topo: dirs no acervo com SKILL.md direto.
function Get-BridgeLeaves {
    Get-ChildItem -LiteralPath $script:Center -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
        ForEach-Object Name | Sort-Object
}

# Bundles: dirs sem SKILL.md próprio mas com sub-skills (o agrupamento que as
# ferramentas de 1 nível não enxergam — é por isso que existe o flatten).
function Get-BridgeBundles {
    Get-ChildItem -LiteralPath $script:Center -Directory |
        Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')) -and
            @(Get-ChildItem -LiteralPath $_.FullName -Recurse -Depth 1 -Filter 'SKILL.md' -File).Count -gt 0
        } |
        ForEach-Object Name | Sort-Object
}

# Resolve uma spec explícita do config para o caminho real no acervo.
function Resolve-BridgeSrc([string]$Spec) {
    $src = Join-Path $script:Center ($Spec -replace '/', '\')
    if ((Test-Path -LiteralPath $src) -and (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) {
        return $src
    }
    return $null
}

# Quantos links válidos (resolvem para dentro do acervo, alvo existente) há em $Dir.
function Get-BridgeCountVisible([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return 0 }
    $n = 0
    foreach ($e in Get-ChildItem -LiteralPath $Dir -Force) {
        if (-not $e.LinkType) { continue }
        $t = @($e.Target)[0]
        if (-not $t) { continue }
        if (-not (Test-Path -LiteralPath $e.FullName)) { continue }
        if (Test-BridgeInsideCenter $t) { $n++ }
    }
    return $n
}

# ---------------------------------------------------------------------------
# Escrita — só muta $HOME no modo apply
# ---------------------------------------------------------------------------

# Garante que $Dest seja link válido para $Src (symlink ou junction).
#  - já resolve para $Src        → ok (nunca backup/remover)
#  - link errado/quebrado        → relink
#  - dir real idêntico ao acervo → backup + link (conversão)
#  - dir real diferente          → alerta + skip (retorna sem tocar)
function Invoke-BridgeEnsureLink([string]$Dest, [string]$Src) {
    $target = Get-DotfilesLinkTarget $Dest
    if ($null -ne $target) {
        if ((ConvertTo-DotfilesNormPath $target) -eq (ConvertTo-DotfilesNormPath $Src)) {
            $script:BridgeNOk++
            return
        }
        Write-Host "  $(Get-BridgeLabel 'Relink'): $Dest (apontava para outro lugar)"
        bridge_drift
        if (bridge_is_apply) {
            Remove-DotfilesLink $Dest
            $null = New-DotfilesLink $Dest $Src
        }
        $script:BridgeNRelink++
        return
    }
    if (Test-Path -LiteralPath $Dest) {
        $isDir = (Get-Item -LiteralPath $Dest -Force).PSIsContainer
        if ($isDir -and (Test-DotfilesDirsIdentical $Src $Dest)) {
            if (bridge_is_apply) {
                $null = Backup-DotfilesDest $Dest
                $null = New-DotfilesLink $Dest $Src
            } else {
                Write-Host "  $(Get-BridgeLabel 'Convert (backup+link)'): $Dest"
                bridge_drift
            }
            $script:BridgeNConvert++
            return
        }
        bridge_warn "SKIP: $Dest difere do acervo — não foi tocado (confira manualmente)"
        $script:BridgeNSkipDiff++
        bridge_drift
        return
    }
    if (bridge_is_apply) {
        try {
            $null = New-DotfilesLink $Dest $Src
        } catch {
            Write-Host "  ERRO: não foi possível criar $Dest ($($_.Exception.Message))"
            $script:BridgeNError++
            return
        }
    }
    bridge_drift
    $script:BridgeNCreated++
}

# Junction/symlink gerenciado órfão: aponta para dentro do acervo, mas o alvo
# não existe mais (skill removida). Removido para não confundir a ferramenta.
function Invoke-BridgeCleanupOrphans([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return }
    foreach ($e in Get-ChildItem -LiteralPath $Dir -Force) {
        if (-not $e.LinkType) { continue }
        $t = @($e.Target)[0]
        if (-not $t) { continue }
        if (-not (Test-BridgeInsideCenter $t)) { continue }
        if (Test-Path -LiteralPath $e.FullName) { continue }
        Write-Host "  $(Get-BridgeLabel 'Removido órfão'): $($e.FullName) (alvo $t não existe mais)"
        bridge_drift
        if (bridge_is_apply) { $e.Delete() }
        $script:BridgeNOrphan++
    }
}

# Normaliza um dir de tool que É o acervo central (alias) em links por-skill.
# Remove só o link (a fonte, o repo, nunca é tocada).
function Invoke-BridgeNormalizeAlias([string]$Dir) {
    $target = Get-DotfilesLinkTarget $Dir
    if ($null -eq $target) { return }
    $center = ConvertTo-DotfilesNormPath $script:Center
    $centerReal = ConvertTo-DotfilesNormPath (Get-BridgeCenterReal)
    $norm = ConvertTo-DotfilesNormPath $target
    if ($norm -eq $center -or $norm -eq $centerReal) {
        Write-Host "  $(Get-BridgeLabel 'Normalizado alias→per-skill'): $Dir (link removido; acervo intacto)"
        bridge_drift
        if (bridge_is_apply) { Remove-DotfilesLink $Dir }
        $script:BridgeNAlias++
    }
}

# ---------------------------------------------------------------------------
# Manifest de customização (Antigravity: ~/.gemini/config/skills.json)
# 1 entry para a raiz (leaves) + 1 por bundle. Caminhos "~/..." portáteis —
# resolvidos pelo próprio Antigravity (path home-relative), independentemente
# de symlink.
# ---------------------------------------------------------------------------
function Write-BridgeManifest([string]$Tool) {
    if (-not $script:ToolManifest.ContainsKey($Tool)) { return }
    $file = $script:ToolManifest[$Tool]
    $bundles = @(Get-BridgeBundles)
    $lines = @('    { "path": "~/.agents/skills" }') +
        @($bundles | ForEach-Object { '    { "path": "~/.agents/skills/' + $_ + '" }' })
    $content = "{`n  `"entries`": [`n" + ($lines -join ",`n") + "`n  ]`n}`n"
    $nEntries = ([regex]::Matches($content, '"path"')).Count

    $upToDate = $false
    if (Test-Path -LiteralPath $file) {
        $upToDate = ([System.IO.File]::ReadAllText($file) -eq $content)
    }
    if ($upToDate) {
        Write-Host "  Manifest em dia: $file ($nEntries entries)"
        return
    }

    if (Test-Path -LiteralPath $file) {
        # Só sobrescreve com backup datado: nunca perde um manifest editado à mão.
        if (bridge_is_apply) { $null = Backup-DotfilesDest $file }
        bridge_drift
    } else {
        bridge_drift
    }
    if (bridge_is_apply) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
        [System.IO.File]::WriteAllText($file, $content, (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Host "  Manifest [$($script:BridgeMode)]: $file ($nEntries entries)"
    $script:BridgeNManifest++
}

# ---------------------------------------------------------------------------
# Bridge por tool
# ---------------------------------------------------------------------------
function Invoke-BridgeTool([string]$Tool, [string]$Spec) {
    if ($Spec -eq '@manifest') {
        Write-BridgeManifest $Tool
        return
    }
    foreach ($dir in $script:ToolDirs[$Tool]) {
        # Alias do acervo → normaliza ANTES do mkdir: o alias É o dir.
        Invoke-BridgeNormalizeAlias $dir
        if (bridge_is_apply) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        $expected = 0
        if ($Spec -eq '*') {
            foreach ($skill in Get-BridgeLeaves) {
                $expected++
                Write-Host "→ $Tool [$(Split-Path $dir -Leaf)] $skill"
                Invoke-BridgeEnsureLink (Join-Path $dir $skill) (Join-Path $script:Center $skill)
            }
        } elseif ($Spec -eq '**') {
            foreach ($name in $script:BridgeSkillNames) {
                $rel = $script:BridgeSkills[$name]
                $expected++
                Write-Host "→ $Tool [$(Split-Path $dir -Leaf)] $name ← $rel"
                Invoke-BridgeEnsureLink (Join-Path $dir $name) (Join-Path $script:Center ($rel -replace '/', '\'))
            }
        } else {
            $src = Resolve-BridgeSrc $Spec
            if ($null -ne $src) {
                $skill = Split-Path $src -Leaf
                $expected = 1
                Write-Host "→ $Tool [$(Split-Path $dir -Leaf)] $Spec (src=$src)"
                Invoke-BridgeEnsureLink (Join-Path $dir $skill) $src
            } else {
                Write-Host "  AVISO: skill não encontrada no acervo: $Spec"
            }
        }
        Invoke-BridgeCleanupOrphans $dir
        $visible = Get-BridgeCountVisible $dir
        if ($script:BridgeMode -eq 'doctor') {
            $status = if ($visible -eq $expected) { 'ok' } else { 'DRIFT' }
        } else {
            $status = "$visible/$expected"
        }
        $null = $script:BridgeRows.Add([pscustomobject]@{
            Tool = $Tool; Root = $dir; Expected = $expected; Visible = $visible; Status = $status
        })
    }
}

# Nomes fora do padrão + colisões de basename: avisados 1x por execução, antes
# de aplicar (nunca corrigidos automaticamente: SKILL.md é fonte versionada).
function Invoke-BridgeHygiene {
    foreach ($c in $script:BridgeCollisions) {
        bridge_warn "colisão de basename: '$($c.Name)' existe em '$($c.Rel1)' e em '$($c.Rel2)' — ambas ignoradas (renomeie no acervo)"
    }
    foreach ($name in $script:BridgeSkillNames) {
        if (-not (Test-BridgeNameOk $name)) {
            $script:BridgeNNameWarn++
            bridge_warn "nome fora do padrão (pode não virar slash command): '$name'"
        }
    }
}

function Show-BridgeSummary {
    Write-Host ''
    Write-Host ('{0,-12} {1,-44} {2,8} {3,8}  {4}' -f 'TOOL', 'ROOT', 'ESPERADO', 'VISÍVEIS', 'ESTADO')
    Write-Host ('─' * 88)
    foreach ($row in $script:BridgeRows) {
        Write-Host ('{0,-12} {1,-44} {2,8} {3,8}  {4}' -f $row.Tool, $row.Root, $row.Expected, $row.Visible, $row.Status)
    }
    Write-Host ''
    Write-Host '── Bridge de skills ───────────────────────────────────────────'
    Write-Host ("  criados:            {0}" -f $script:BridgeNCreated)
    Write-Host ("  já ok:              {0}" -f $script:BridgeNOk)
    Write-Host ("  relinkados:         {0}" -f $script:BridgeNRelink)
    Write-Host ("  convertidos (bkp):  {0}" -f $script:BridgeNConvert)
    Write-Host ("  alias normalizados: {0}" -f $script:BridgeNAlias)
    Write-Host ("  órfãos removidos:   {0}" -f $script:BridgeNOrphan)
    Write-Host ("  manifest gerado:    {0}" -f $script:BridgeNManifest)
    Write-Host ("  colisões basename:  {0}" -f $script:BridgeNCollision)
    Write-Host ("  nomes fora padrão:  {0}" -f $script:BridgeNNameWarn)
    Write-Host ("  pulados (divergem): {0}" -f $script:BridgeNSkipDiff)
    Write-Host ("  erros de escrita:   {0}" -f $script:BridgeNError)
    Write-Host ("  drift detectado:    {0}" -f $script:BridgeDrift)
    Write-Host '───────────────────────────────────────────────────────────────'
    if ($script:BridgeMode -eq 'doctor' -and $script:BridgeWarnings.Count -gt 0) {
        Write-Host ''
        Write-Host ("  Avisos ({0}):" -f $script:BridgeWarnings.Count)
        foreach ($w in $script:BridgeWarnings) { Write-Host "   - $w" }
    }
}

function Invoke-BridgeMain {
    if (-not (Test-Path -LiteralPath $script:Center)) {
        Write-Error "acervo central não encontrado: $($script:Center)"
        Write-Error 'Execute scripts/install-dotfiles.ps1 antes (cria o link ~/.agents).'
        exit 1
    }
    if (-not (Test-Path -LiteralPath $script:ConfigFile)) {
        Write-Error "configuração não encontrada: $($script:ConfigFile)"
        exit 1
    }

    Invoke-BridgeDiscover

    switch ($script:BridgeMode) {
        'doctor' { Write-Host 'MODO: -Doctor (read-only)' }
        'dry-run' { Write-Host 'MODO: -DryRun (nada é escrito)' }
        default { Write-Host "Bridge de skills → acervo central $($script:Center)" }
    }
    Write-Host "Config: $($script:ConfigFile)"
    Write-Host ("Acervo: {0} skills em {1} leaves + {2} bundles" -f `
        $script:BridgeSkillNames.Count, @(Get-BridgeLeaves).Count, @(Get-BridgeBundles).Count)
    Write-Host ''

    Invoke-BridgeHygiene

    foreach ($raw in Get-Content -LiteralPath $script:ConfigFile) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $line = ($line -split '#', 2)[0].Trim()
        $pipe = $line.IndexOf('|')
        if ($pipe -lt 1 -or $pipe -eq $line.Length - 1) {
            Write-Host "  AVISO: linha inválida ignorada: $raw"
            continue
        }
        $tool = $line.Substring(0, $pipe).Trim()
        $spec = $line.Substring($pipe + 1).Trim()
        if (-not $script:ToolDirs.ContainsKey($tool)) {
            Write-Host "  AVISO: ferramenta desconhecida: $tool"
            continue
        }
        Invoke-BridgeTool $tool $spec
        Write-Host ''
    }

    Show-BridgeSummary

    if ($script:BridgeMode -eq 'doctor') {
        if ($script:BridgeDrift -gt 0) {
            Write-Host ''
            Write-Host "→ $($script:BridgeDrift) divergência(s). Para convergir: scripts/install-agent-skills-bridge.ps1"
            exit 1
        }
        Write-Host ''
        Write-Host '→ Tudo convergido com o acervo central.'
        exit 0
    }
}

Invoke-BridgeMain
