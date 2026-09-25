# clause: B3.4
# P-17: the default task is composed from the tree.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    $expected = @('Clean', 'Toolchain', 'Manifest', 'Analyze', 'Plan')
    if (Test-Path -LiteralPath (Join-Path $root 'audit') -PathType Container) { $expected += 'Audit' }
    $expected += 'Unit'
    if (Get-ChildItem -Path (Join-Path $root 'tests/chain') -Filter 'C-*.ps1' -File -ErrorAction Ignore) { $expected += 'Chain' }
    if (Get-ChildItem -Path (Join-Path $root 'tests/heaven') -Filter 'M-*.ps1' -File -ErrorAction Ignore) { $expected += 'Heaven' }
    $expected += 'Package', 'Lift'

    $all = Invoke-Build ?? -File (Join-Path $root 'Genesis.build.ps1')
    $actual = @($all['.'].Jobs)
}

Describe 'P-17' {
    It 'default equals the composition the tree implies' {
        $actual -join ',' | Should -BeExactly ($expected -join ',')
    }

    It 'every B3 task is defined' {
        foreach ($name in 'Clean', 'Toolchain', 'Manifest', 'Analyze', 'Plan', 'Audit', 'Unit', 'Chain', 'Heaven', 'Package', 'Lift', 'Payload', 'Receive', 'Grade') {
            $all.Contains($name) | Should -BeTrue -Because "$name is in the B3 table"
        }
    }
}
