# status: red
# spec: S2.2, S2.3
# C-16: one receipt renamed -> NAME_MISMATCH.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-16' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3
        $clean = Test-ChainVerify $run
        $newName = (Get-ChainTextSha256 'renamed') + '.json'
        Rename-Item -LiteralPath (Get-ChainReceiptPath $run $tree[2]) -NewName $newName
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the tree verifies before the rename' {
        Assert-ChainExit $clean OK
    }

    It 'the renamed head is NAME_MISMATCH' {
        Assert-ChainExit $result NAME_MISMATCH
    }
}
