# status: red
# spec: S2.2, S2.3
# C-16: one receipt renamed -> NAME_MISMATCH.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-16' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $newName = (Get-HarnessTextSha 'some other name') + '.json'
        Rename-Item -LiteralPath (Get-HarnessReceiptPath $run $tree[2]) -NewName $newName
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit NAME_MISMATCH' {
        Assert-HarnessExit $result NAME_MISMATCH
    }
}
