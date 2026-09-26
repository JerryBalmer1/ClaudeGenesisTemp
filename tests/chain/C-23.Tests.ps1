# status: red
# spec: S3.4, S8.2
# C-23: receipt_type receipt with actor.kind successor -> ACTOR_ILLEGAL. Signed by the successor whose
# fingerprint it carries, so the actor rule is the only thing wrong with it.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-23' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $null = Edit-HarnessReceipt $run $tree[1] {
            param($r)
            $r.actor.kind = 'successor'
            $r.actor.fingerprint = $run.Succ1.Fingerprint
        } -SignWith $run.Succ1
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit ACTOR_ILLEGAL' {
        Assert-HarnessExit $result ACTOR_ILLEGAL
    }
}
