# clause: B6.3
# P-09: GOD_PLAN.md and SPEC.md carry no commit sha, file:line reference, live count, or numbered range.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $patterns = [ordered]@{
        'commit sha'     = '(?<![0-9A-Za-z])(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}(?![0-9A-Za-z])'
        'file:line'      = '[\w./-]+\.(ps1|psm1|psd1|md|json|ya?ml|py|txt)(:|#L)\d+'
        'live count'     = '(?i)(?<![\w.-])\d+\s+(tests?|files?|receipts?|mutants?|commits?|checks?|passing|failing|failures?)\b'
        'numbered range' = '\b[A-Z]{1,2}-?\d+(\.\d+)?\s*(…|\.\.\.?|–|\bto\b)\s*[A-Z]{0,2}-?\d+'
    }

    function Find-Forbidden([string]$file) {
        $text = [IO.File]::ReadAllText((Join-Path $root $file))
        foreach ($kind in $patterns.Keys) {
            foreach ($m in [regex]::Matches($text, $patterns[$kind])) { "$file $kind '$($m.Value)'" }
        }
    }
}

Describe 'P-09' {
    It '<_> has no forbidden tokens' -ForEach @('GOD_PLAN.md', 'SPEC.md') {
        Find-Forbidden $_ | Should -BeNullOrEmpty
    }
}
