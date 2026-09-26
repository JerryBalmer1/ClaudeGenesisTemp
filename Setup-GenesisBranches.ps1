#requires -Version 7.4
<#
.SYNOPSIS
  Branch setup for the two repos that are in play. Uses gh. Nothing else.

.DESCRIPTION
  Allowed repos: JerryBalmer1/ClaudeGenesisTemp and JerryBalmer1/ClaudeChain.
  Any other repo throws. This script never touches claude.agent.* or TerraformAST.

  Two flows. Same guardrails on both. Nobody is on the bypass list, including Jerry.

    Normal:    claude|grok|fable|opus/<name>  --PR-->  develop
    Override:  same head                       --PR-->  main
               only when Jerry said so, and the PR body contains the line
               "override: jerry"

  develop gets its own ruleset, develop-protect, cloned from what main already
  enforces (ruleset 24026011). This script does not edit main-protect.

    * pull request required, zero required approvals
    * strict required checks: build (ubuntu-latest), build (windows-latest),
      pr-body, audit
    * no force-push
    * no delete
    * bypass list empty

  B8.2, in .github/workflows/ci.yml on ClaudeGenesisTemp, rejects a PR whose
  head is not under claude/, grok/, fable/, or opus/. A PR from the branch
  named develop into main fails that check today. This script does not invent
  a claude/promote-* branch to sneak past it, and it does not weaken the check.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Owner = 'JerryBalmer1',
    [ValidateSet('ClaudeGenesisTemp', 'ClaudeChain')]
    [string]$Repo = 'ClaudeGenesisTemp'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$script:AllowedHeads = @('claude', 'grok', 'fable', 'opus')
$script:MainRulesetName = 'main-protect'
$script:DevelopRulesetName = 'develop-protect'
$script:RequiredChecks = @(
    'build (ubuntu-latest)',
    'build (windows-latest)',
    'pr-body',
    'audit'
)

function Invoke-Gh {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [string]$Body
    )
    if ($PSBoundParameters.ContainsKey('Body')) {
        $out = $Body | & gh @Args | Out-String
    }
    else {
        $out = & gh @Args | Out-String
    }
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Args -join ' ') exited $LASTEXITCODE"
    }
    return $out
}

function Get-RepoRulesets {
    $json = Invoke-Gh -Args @(
        'api', '--paginate',
        "repos/$Owner/$Repo/rulesets"
    )
    $items = @($json | ConvertFrom-Json)
    if ($items.Count -eq 1 -and $items[0] -is [System.Array]) {
        return @($items[0])
    }
    return $items
}

function Get-Ruleset {
    param([Parameter(Mandatory = $true)][int]$Id)
    $json = Invoke-Gh -Args @(
        'api',
        "repos/$Owner/$Repo/rulesets/$Id"
    )
    return ($json | ConvertFrom-Json)
}

function New-ProtectRules {
    param([Parameter(Mandatory = $true)][string]$Branch)
    $checks = foreach ($name in $script:RequiredChecks) {
        @{ context = $name }
    }
    return @{
        name        = if ($Branch -eq 'main') { $script:MainRulesetName } else { $script:DevelopRulesetName }
        target      = 'branch'
        enforcement = 'active'
        bypass_actors = @()
        conditions  = @{
            ref_name = @{
                include = @("refs/heads/$Branch")
                exclude = @()
            }
        }
        rules = @(
            @{ type = 'deletion' },
            @{
                type = 'pull_request'
                parameters = @{
                    allowed_merge_methods = @('merge', 'squash', 'rebase')
                    dismiss_stale_reviews_on_push = $false
                    require_code_owner_review = $false
                    require_last_push_approval = $false
                    required_approving_review_count = 0
                    required_review_thread_resolution = $false
                }
            },
            @{
                type = 'required_status_checks'
                parameters = @{
                    do_not_enforce_on_create = $false
                    strict_required_status_checks_policy = $true
                    required_status_checks = @($checks)
                }
            },
            @{ type = 'non_fast_forward' }
        )
    }
}

function Assert-MainUntouched {
    $listed = @(Get-RepoRulesets | Where-Object { $_.name -eq $script:MainRulesetName })
    if ($listed.Count -ne 1) {
        throw "expected exactly one ruleset named $($script:MainRulesetName), found $($listed.Count). Not creating develop on a repo whose main rule is missing."
    }
    $live = Get-Ruleset -Id ([int]$listed[0].id)
    $problems = @()
    if (@($live.bypass_actors).Count -ne 0) {
        $problems += 'main-protect bypass list is not empty'
    }
    $types = @($live.rules | ForEach-Object { $_.type })
    foreach ($need in @('deletion', 'pull_request', 'required_status_checks', 'non_fast_forward')) {
        if ($need -notin $types) { $problems += "main-protect missing rule $need" }
    }
    $status = @($live.rules | Where-Object { $_.type -eq 'required_status_checks' })
    if ($status.Count -ne 1 -or -not $status[0].parameters.strict_required_status_checks_policy) {
        $problems += 'main-protect status checks are not strict'
    }
    else {
        $have = @($status[0].parameters.required_status_checks | ForEach-Object { $_.context })
        foreach ($need in $script:RequiredChecks) {
            if ($need -notin $have) { $problems += "main-protect missing check '$need'" }
        }
    }
    $pr = @($live.rules | Where-Object { $_.type -eq 'pull_request' })
    if ($pr.Count -ne 1 -or [int]$pr[0].parameters.required_approving_review_count -ne 0) {
        $problems += 'main-protect approval count is not zero'
    }
    if ($problems.Count) {
        throw ("main-protect (id $($live.id)) does not match the metal. This script will not rewrite it.`n" + ($problems -join "`n"))
    }
    return $live
}

function Ensure-DevelopBranch {
    $mainJson = Invoke-Gh -Args @('api', "repos/$Owner/$Repo/git/ref/heads/main")
    $main = $mainJson | ConvertFrom-Json
    $sha = [string]$main.object.sha
    if (-not $sha) { throw "refs/heads/main has no sha. $Owner/$Repo is empty; create main first." }

    $exists = $true
    try {
        $null = Invoke-Gh -Args @('api', "repos/$Owner/$Repo/git/ref/heads/develop")
    }
    catch {
        if ("$_" -notmatch '404') { throw }
        $exists = $false
    }
    if ($exists) {
        $dev = (Invoke-Gh -Args @('api', "repos/$Owner/$Repo/git/ref/heads/develop") | ConvertFrom-Json)
        Write-Host "develop already exists at $($dev.object.sha). Not moving it."
        return [string]$dev.object.sha
    }
    if ($PSCmdlet.ShouldProcess("$Owner/$Repo", "create refs/heads/develop at $sha")) {
        $body = @{ ref = 'refs/heads/develop'; sha = $sha } | ConvertTo-Json -Compress
        $null = Invoke-Gh -Body $body -Args @('api', '--method', 'POST', "repos/$Owner/$Repo/git/refs", '--input', '-')
    }
    return $sha
}

function Ensure-DevelopRuleset {
    $payload = New-ProtectRules -Branch 'develop'
    $json = $payload | ConvertTo-Json -Depth 8
    $listed = @(Get-RepoRulesets | Where-Object { $_.name -eq $script:DevelopRulesetName })
    if ($listed.Count -gt 1) {
        throw "more than one ruleset named $($script:DevelopRulesetName)"
    }
    if ($listed.Count -eq 1) {
        $id = [int]$listed[0].id
        if ($PSCmdlet.ShouldProcess("$Owner/$Repo ruleset $id", 'update develop-protect in place')) {
            $null = Invoke-Gh -Body $json -Args @('api', '--method', 'PUT', "repos/$Owner/$Repo/rulesets/$id", '--input', '-')
        }
        return $id
    }
    if ($PSCmdlet.ShouldProcess("$Owner/$Repo", 'create ruleset develop-protect')) {
        $created = Invoke-Gh -Body $json -Args @('api', '--method', 'POST', "repos/$Owner/$Repo/rulesets", '--input', '-')
        return [int](($created | ConvertFrom-Json).id)
    }
    return 0
}

function Assert-AgentHead {
    param([Parameter(Mandatory = $true)][string]$Head)
    $prefix = ($Head -split '/')[0]
    if ($prefix -notin $script:AllowedHeads -or $Head -notlike "$prefix/*") {
        throw "head '$Head' is not under $($script:AllowedHeads -join '/, ')/. B8.2 would fail the PR. Refusing."
    }
}

function New-GenesisPullRequest {
    <#
      Normal path targets develop.
      -JerrySaidOverride targets main and requires a body line "override: jerry".
      Same checks either way. This does not push the head branch; it has to
      already be on origin.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$Head,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Body,
        [switch]$JerrySaidOverride,
        [string]$Owner = 'JerryBalmer1',
        [ValidateSet('ClaudeGenesisTemp', 'ClaudeChain')]
        [string]$Repo = 'ClaudeGenesisTemp'
    )
    Assert-AgentHead -Head $Head
    $base = 'develop'
    if ($JerrySaidOverride) {
        $ok = $false
        foreach ($line in ($Body -split '\r?\n')) {
            if ($line.Trim() -ceq 'override: jerry') { $ok = $true }
        }
        if (-not $ok) {
            throw "override path refused. Body must contain a line that is exactly 'override: jerry'. Jerry says it, the PR records it."
        }
        $base = 'main'
    }
    if ($PSCmdlet.ShouldProcess("$Owner/$Repo", "pr $Head -> $base")) {
        Invoke-Gh -Args @(
            'pr', 'create',
            '--repo', "$Owner/$Repo",
            '--base', $base,
            '--head', $Head,
            '--title', $Title,
            '--body', $Body
        )
    }
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

if ($Repo -notin @('ClaudeGenesisTemp', 'ClaudeChain')) {
    throw "refusing repo $Repo. Only ClaudeGenesisTemp and ClaudeChain."
}

$null = Invoke-Gh -Args @('auth', 'status')
$mainLive = Assert-MainUntouched
$developSha = Ensure-DevelopBranch
$developId = Ensure-DevelopRuleset

Write-Host ""
Write-Host "repo:           $Owner/$Repo"
Write-Host "main-protect:   id $($mainLive.id)  bypass empty  (not modified)"
Write-Host "develop:        $developSha"
Write-Host "develop-protect id $developId"
Write-Host "normal:         <claude|grok|fable|opus>/*  ->  develop"
Write-Host "override:       same head -> main, only with -JerrySaidOverride and body line 'override: jerry'"
Write-Host "not done:       a PR whose head is the branch 'develop' still fails B8.2. No bypass was added to get around that."
