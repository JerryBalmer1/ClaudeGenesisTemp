# status: red
# spec: S11.2, S7.6, S7.8
# C-25: refuse-on-bad-tail. A writer on a chain that does not verify exits the verifier's class and writes
# nothing. After a root-revocation the chain is frozen: the revocation itself was written on a clean
# chain, and every later write is refused and writes nothing.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
    $classes = 'SCHEMA', 'ACTOR_ILLEGAL', 'CHAIN_BREAK', 'SIG_FAIL', 'HASH_MISMATCH', 'NAME_MISMATCH', 'CONTENT_ABSENT', 'DISCREPANCY', 'REVOKED', 'WALK_LIMIT', 'IO'
}

Describe 'C-25' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3

        $renamed = New-HarnessCopy $run 'renamed'
        Rename-Item -LiteralPath (Get-HarnessReceiptPath $run $tree[2] $renamed) -NewName ((Get-HarnessTextSha 'elsewhere') + '.json')
        $renamedBefore = Get-HarnessSnapshot $renamed
        $renamedWrite = Invoke-Genesis $run 'New-GenesisReceipt' (Get-HarnessReceiptParameters $run) -Heaven $renamed
        $renamedAfter = Get-HarnessSnapshot $renamed

        $flipped = New-HarnessCopy $run 'flipped'
        Invoke-HarnessSignatureFlip (Get-HarnessReceiptPath $run $tree[1] $flipped)
        $flippedBefore = Get-HarnessSnapshot $flipped
        $flippedWrite = Invoke-Genesis $run 'New-GenesisDiscrepancy' (Get-HarnessDiscrepancyParameters $run) -Heaven $flipped
        $flippedAfter = Get-HarnessSnapshot $flipped

        $frozen = New-HarnessCopy $run 'frozen'
        $revokeRoot = Invoke-Genesis $run 'Add-GenesisRevocation' @{ RevokeRoot = $true; SigningKeyId = $run.Succ1.KeyId } -Heaven $frozen
        $frozenBefore = Get-HarnessSnapshot $frozen
        $frozenReceipt = Invoke-Genesis $run 'New-GenesisReceipt' (Get-HarnessReceiptParameters $run) -Heaven $frozen
        $frozenAmend = Invoke-Genesis $run 'Add-GenesisAmendment' (Get-HarnessAmendmentParameters $run) -Heaven $frozen
        $frozenAfter = Get-HarnessSnapshot $frozen
    }
    AfterAll { Remove-HarnessRun $run }

    It 'renamed tail: the writer exits NAME_MISMATCH and writes nothing' {
        Assert-HarnessExit $renamedWrite NAME_MISMATCH
        $renamedAfter | Should -BeExactly $renamedBefore
    }

    It 'flipped signature: the writer exits SIG_FAIL and writes nothing' {
        Assert-HarnessExit $flippedWrite SIG_FAIL
        $flippedAfter | Should -BeExactly $flippedBefore
    }

    It 'the root-revocation is written on the clean chain' {
        Assert-HarnessExit $revokeRoot OK
        $revokeRoot.Written.Count | Should -Be 1
    }

    It 'after root-revocation, <_> is refused with a class' -ForEach @('receipt', 'amendment') {
        $r = if ($_ -eq 'receipt') { $frozenReceipt } else { $frozenAmend }
        $r.ExitCode | Should -Not -Be 0 -Because (Format-HarnessResult $r)
        $r.Class | Should -BeIn $classes -Because (Format-HarnessResult $r)
    }

    It 'after root-revocation, nothing is written' {
        $frozenAfter | Should -BeExactly $frozenBefore
    }
}
