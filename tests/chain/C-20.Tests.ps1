# status: red
# spec: S3.4
# C-20: an actor.kind outside root | operator-attributed | successor -> ACTOR_ILLEGAL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-20' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $null = Edit-HarnessReceipt $run $tree[1] { param($r) $r.actor.kind = 'system' } -SignWith $run.Root
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit ACTOR_ILLEGAL' {
        Assert-HarnessExit $result ACTOR_ILLEGAL
    }
}
