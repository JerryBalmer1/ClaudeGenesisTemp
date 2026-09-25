# clause: B3.4
# clause: B6.1
# P-12: no short-circuit switch is declared and no CI environment check exists.
# P-12b: neither GOD_PLAN.md nor SPEC.md cites a chat round.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $banned = 'Force', 'SkipTests', 'NoSign', 'SkipHeaven', 'SkipAudit'
    $ciVariable = 'env:' + 'CI'
    $scripts = @(
        foreach ($dir in 'src', 'tests') { Get-ChildItem -Path (Join-Path $root $dir) -Include '*.ps1', '*.psm1' -Recurse -File }
        foreach ($file in 'build.ps1', 'Genesis.build.ps1', 'grade.ps1') { Get-Item -LiteralPath (Join-Path $root $file) }
    )

    function Find-Ast($file, [scriptblock]$predicate) {
        $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        $ast.FindAll($predicate, $true) | ForEach-Object { "$([IO.Path]::GetRelativePath($root, $file.FullName)):$($_.Extent.StartLineNumber)" }
    }
}

Describe 'P-12' {
    It 'no script declares a short-circuit parameter' {
        $hits = foreach ($f in $scripts) {
            Find-Ast $f { param($n) $n -is [Management.Automation.Language.ParameterAst] -and $n.Name.VariablePath.UserPath -in $banned }
        }
        $hits | Should -BeNullOrEmpty
    }

    It 'no script reads the CI environment variable' {
        $hits = foreach ($f in $scripts) {
            Find-Ast $f { param($n) $n -is [Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -eq $ciVariable }
        }
        $hits | Should -BeNullOrEmpty
    }

    It 'ci.yml does not read the CI environment variable' {
        $yml = [IO.File]::ReadAllText((Join-Path $root '.github/workflows/ci.yml'))
        $yml.Contains('$' + $ciVariable, [StringComparison]::OrdinalIgnoreCase) | Should -BeFalse
    }

    It 'P-12b: <_> cites no chat round' -ForEach @('GOD_PLAN.md', 'SPEC.md') {
        [IO.File]::ReadAllText((Join-Path $root $_)) | Should -Not -Match '(?i)\bround\s+\d'
    }
}
