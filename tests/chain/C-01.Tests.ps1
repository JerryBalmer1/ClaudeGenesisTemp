# status: red
# spec: S7.1, S7.2, S1.3
# C-01: three receipts verify from a different absolute path.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-01' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = New-HarnessTree $run 3
        $moved = Join-Path $TestDrive 'elsewhere/deeper/heaven'
        Copy-HarnessHeaven $run.Heaven $moved
        Remove-Item -LiteralPath $run.Heaven -Recurse
        $result = Test-HarnessChain $run -Heaven $moved
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the copied Heaven holds three receipts' {
        (Get-HarnessNames $moved).Count | Should -Be 3
    }

    It 'verifies with the original path gone' {
        Assert-HarnessExit $result OK
    }
}
