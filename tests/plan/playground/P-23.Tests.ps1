# clause: B11.1
# P-23: no report/ anywhere in the playground or the payload; grade.ps1 exists to be shipped (A4).

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

Describe 'P-23' {
    It 'grade.ps1 exists' {
        Join-Path $root 'grade.ps1' | Should -Exist
    }

    It 'no report directory in the working tree' {
        $hits = Get-ChildItem -LiteralPath $root -Directory -Force | Where-Object Name -NotIn '.git', '.tools' | ForEach-Object {
            if ($_.Name -eq 'report') { $_ }
            Get-ChildItem -LiteralPath $_.FullName -Recurse -Directory -Force -Filter 'report'
        } | ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) }
        $hits | Should -BeNullOrEmpty
    }

    It 'no tracked path under a report directory' {
        @(git -C $root ls-files | Where-Object { $_ -match '(^|/)report/' }) | Should -BeNullOrEmpty
    }

    It 'no report path in the committed payload manifest' {
        $manifest = Get-Content -LiteralPath (Join-Path $root 'payload.manifest.json') -Raw | ConvertFrom-Json
        @($manifest.files | Where-Object { $_.path -match '(^|/)report/' }) | Should -BeNullOrEmpty
    }
}
