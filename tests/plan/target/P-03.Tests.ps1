# status: red
# clause: B1.1
# spec: S1.1
# P-03: S1.1 == FunctionsToExport == Public/*.ps1. Red until all S1.1 names exist (A1.2).

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $spec = [IO.File]::ReadAllText((Join-Path $root 'SPEC.md'))
    $block = [regex]::Match($spec, '(?s)\*\*S1\.1\*\*.*?```\r?\n(.*?)```').Groups[1].Value
    $specNames = @($block -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object)
    $exported = @((Import-PowerShellDataFile -Path (Join-Path $root 'src/Genesis/Genesis.psd1')).FunctionsToExport | Where-Object { $_ } | Sort-Object)
    $public = @(Get-ChildItem -Path (Join-Path $root 'src/Genesis/Public') -Filter '*.ps1' -File | ForEach-Object BaseName | Sort-Object)
}

Describe 'P-03' {
    It 'S1.1 lists the public surface' {
        $specNames.Count | Should -BeGreaterThan 0
    }

    It 'FunctionsToExport equals S1.1' {
        $exported -join ',' | Should -BeExactly ($specNames -join ',')
    }

    It 'Public/*.ps1 equals S1.1' {
        $public -join ',' | Should -BeExactly ($specNames -join ',')
    }
}
