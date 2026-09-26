# status: red
# spec: S3.2
# C-11: backwards claimed_time is accepted.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-11' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3
        $previous = Read-ChainReceipt (Get-ChainReceiptPath $run $tree[1])
        $head = Edit-ChainReceipt -Run $run -Hash $tree[2] -SignWith $run.Root -Mutate { param($r) $r.claimed_time = $previous.claimed_time - 86400 }
        $headReceipt = Read-ChainReceipt (Get-ChainReceiptPath $run $head)
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the head claims a time before its parent' {
        $headReceipt.claimed_time | Should -BeLessThan $previous.claimed_time
    }

    It 'the chain verifies' {
        Assert-ChainExit $result OK
    }
}
