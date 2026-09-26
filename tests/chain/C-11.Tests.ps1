# status: red
# spec: S3.2
# C-11: a claimed_time earlier than the parent's is accepted; the field is advisory.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-11' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $parentTime = (Read-HarnessReceipt $run $tree[1]).claimed_time
        $head = Edit-HarnessReceipt $run $tree[2] { param($r) $r.claimed_time = $parentTime - 86400 } -SignWith $run.Root
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the head claims a time before its parent' {
        (Read-HarnessReceipt $run $head).claimed_time | Should -BeLessThan $parentTime
    }

    It 'the chain verifies' {
        Assert-HarnessExit $result OK
    }
}
