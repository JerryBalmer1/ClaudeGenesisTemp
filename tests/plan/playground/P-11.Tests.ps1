# clause: A1.1
# P-11: .gitignore lists .heaven/, .tools/, out/; nothing under src/, tests/, audit/ is ignored.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $lines = @(Get-Content -LiteralPath (Join-Path $root '.gitignore') | ForEach-Object { $_.Trim() })
}

Describe 'P-11' {
    It '.gitignore lists <_>' -ForEach @('.heaven/', '.tools/', 'out/') {
        $lines | Should -Contain $_
    }

    It 'no tracked file under src/, tests/, audit/ matches an ignore rule' {
        git -C $root ls-files -ci --exclude-standard -- src tests audit | Should -BeNullOrEmpty
    }

    It 'no ignored file exists under src/, tests/, audit/' {
        git -C $root ls-files -oi --exclude-standard --directory -- src tests audit | Should -BeNullOrEmpty
    }
}
