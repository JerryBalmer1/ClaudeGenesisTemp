# status: red
# spec: S7.1, S7.2, S2.1
# C-02: verify from a renamed top folder.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-02' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = New-HarnessTree $run 3
        Rename-Item -LiteralPath $run.Heaven -NewName 'heaven-renamed'
        $renamed = Join-Path $run.Dir 'heaven-renamed'
        $result = Test-HarnessChain $run -Heaven $renamed
    }
    AfterAll { Remove-HarnessRun $run }

    It 'verifies under the new folder name' {
        Assert-HarnessExit $result OK
    }
}
