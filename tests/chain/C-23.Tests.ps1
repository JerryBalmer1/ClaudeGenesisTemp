# status: red
# spec: S3.4
# C-23: a receipt with actor.kind == successor -> ACTOR_ILLEGAL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-23' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 2
        $null = Edit-ChainReceipt -Run $run -Hash $tree[1] -SignWith $run.Root -Mutate { param($r) $r.actor.kind = 'successor' }
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'receipt_type receipt with kind successor is ACTOR_ILLEGAL' {
        Assert-ChainExit $result ACTOR_ILLEGAL
    }
}
