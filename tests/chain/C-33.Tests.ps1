# status: red
# spec: S9.1, S9.2
# C-33: a PAPER sheet that does not match the cold copy -> HASH_MISMATCH, nothing copied.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-33' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $cold = Join-Path $run.Dir 'cold'
        Copy-HarnessHeaven $run.Heaven $cold -ReceiptsOnly
        Set-HarnessPaper -Cold $cold -Genesis $tree[0] -ReceiptsHash (Get-HarnessTextSha 'not the receipt list')
        $empty = New-HarnessCopy $run 'empty' -Empty
        $before = Get-HarnessSnapshot $empty
        $result = Invoke-Genesis $run 'Restore-GenesisHeaven' @{ ColdPath = $cold; SigningKeyId = $run.Root.KeyId } -Heaven $empty
        $after = Get-HarnessSnapshot $empty
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit HASH_MISMATCH' {
        Assert-HarnessExit $result HASH_MISMATCH
    }

    It 'nothing is copied' {
        (Get-HarnessNames $empty).Count | Should -Be 0
        $after | Should -BeExactly $before
    }
}
