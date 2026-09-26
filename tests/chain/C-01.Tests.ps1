# status: red
# spec: S2.1, S7.2
# C-01: three receipts verify from a different absolute path.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-01' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = New-ChainTree $run 3
        $here = Test-ChainVerify $run
        $elsewhere = Join-Path $run.Dir 'elsewhere/deeper/heaven'
        Copy-ChainHeaven $run.HeavenPath $elsewhere
        Remove-Item -LiteralPath $run.HeavenPath -Recurse -Force
        $there = Test-ChainVerify $run -HeavenPath $elsewhere
    }
    AfterAll { Remove-ChainRun $run }

    It 'three receipts verify where they were written' {
        Assert-ChainExit $here OK
    }

    It 'the same bytes verify from a different absolute path, the original gone' {
        (Get-ChainReceiptName $elsewhere).Count | Should -Be 3
        Assert-ChainExit $there OK
    }
}
