# clause: B5.4
# P-05: no OpenPGP armor in the listed paths. Matches the armor line prefix, not the bare phrase,
# because GOD_PLAN.md B5.4 names the phrase (see the audit/inbox note on B5.4).

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $needle = '-----' + 'BEGIN PGP'
}

Describe 'P-05' {
    It 'no armor block in <_>' -ForEach @('src', 'tests', '.github', '.agents', 'audit', 'GOD_PLAN.md', 'SPEC.md') {
        $path = Join-Path $root $_
        $files = if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path }
        elseif (Test-Path -LiteralPath $path) { Get-ChildItem -LiteralPath $path -Recurse -File -Force }
        $hits = $files | Where-Object { [IO.File]::ReadAllText($_.FullName).Contains($needle) } |
            ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) }
        $hits | Should -BeNullOrEmpty
    }
}
