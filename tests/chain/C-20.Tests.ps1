# status: red
# spec: S3.4
# C-20: unknown actor.kind -> ACTOR_ILLEGAL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-20' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 2
        $null = Edit-ChainReceipt -Run $run -Hash $tree[1] -SignWith $run.Root -Mutate { param($r) $r.actor.kind = 'system' }
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'actor.kind system is ACTOR_ILLEGAL' {
        Assert-ChainExit $result ACTOR_ILLEGAL
    }
}
