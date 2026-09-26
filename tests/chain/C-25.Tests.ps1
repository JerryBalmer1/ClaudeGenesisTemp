# status: red
# spec: S11.2, S7.6
# C-25: refuse on a bad tail: every writer runs Test-GenesisChain first and exits its class, writing nothing.
# Frozen chain: clean for the root-revocation itself, dirty for any write after it.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-25' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3

        $bad = Split-ChainRun $run 'bad'
        Invoke-ChainSignatureFlip (Get-ChainReceiptPath $bad $tree[1])
        $badVerify = Test-ChainVerify $bad
        $badBefore = Get-ChainSnapshot $bad.HeavenPath
        $badWrites = [ordered]@{
            'New-GenesisReceipt'     = Invoke-Genesis -Run $bad -Command 'New-GenesisReceipt' -Parameters (Get-ChainReceiptParameters -Run $bad -Context 'on a bad tail')
            'Add-GenesisAmendment'   = Invoke-Genesis -Run $bad -Command 'Add-GenesisAmendment' -Parameters (Get-ChainAmendmentParameters $bad)
            'New-GenesisDiscrepancy' = Invoke-Genesis -Run $bad -Command 'New-GenesisDiscrepancy' -Parameters (Get-ChainDiscrepancyParameters $bad)
            'Add-GenesisRevocation'  = Invoke-Genesis -Run $bad -Command 'Add-GenesisRevocation' -Parameters @{ Revokes = $tree[2]; SigningKeyId = $run.Root.KeyId }
        }
        $badAfter = Get-ChainSnapshot $bad.HeavenPath

        $frozen = Split-ChainRun $run 'frozen'
        $rootRevocation = Invoke-Genesis -Run $frozen -Command 'Add-GenesisRevocation' -Parameters @{ RevokeRoot = $true; SigningKeyId = $run.Succ1.KeyId }
        $frozenVerify = Test-ChainVerify $frozen
        $frozenBefore = Get-ChainSnapshot $frozen.HeavenPath
        $frozenWrites = [ordered]@{
            'New-GenesisReceipt'                = Invoke-Genesis -Run $frozen -Command 'New-GenesisReceipt' -Parameters (Get-ChainReceiptParameters -Run $frozen -Context 'after the freeze')
            'New-GenesisDiscrepancy'            = Invoke-Genesis -Run $frozen -Command 'New-GenesisDiscrepancy' -Parameters (Get-ChainDiscrepancyParameters $frozen)
            'Add-GenesisRevocation -RevokeRoot' = Invoke-Genesis -Run $frozen -Command 'Add-GenesisRevocation' -Parameters @{ RevokeRoot = $true; SigningKeyId = $run.Succ1.KeyId }
        }
        $frozenAfter = Get-ChainSnapshot $frozen.HeavenPath
    }
    AfterAll { Remove-ChainRun $run }

    It 'the bad tail verifies as SIG_FAIL' {
        Assert-ChainExit $badVerify SIG_FAIL
    }

    It '<_> on the bad tail exits SIG_FAIL' -ForEach @('New-GenesisReceipt', 'Add-GenesisAmendment', 'New-GenesisDiscrepancy', 'Add-GenesisRevocation') {
        Assert-ChainExit $badWrites[$_] SIG_FAIL
    }

    It 'nothing is written on the bad tail' {
        $badAfter | Should -BeExactly $badBefore
    }

    It 'the root-revocation on a clean chain is written' {
        Assert-ChainExit $rootRevocation OK
        $rootRevocation.Written.Count | Should -Be 1
    }

    It 'the frozen chain verifies' {
        Assert-ChainExit $frozenVerify OK
    }

    It '<_> after the root-revocation exits non-zero' -ForEach @('New-GenesisReceipt', 'New-GenesisDiscrepancy', 'Add-GenesisRevocation -RevokeRoot') {
        $frozenWrites[$_].ExitCode | Should -Not -Be 0 -Because (Format-ChainResult $frozenWrites[$_])
    }

    It 'nothing is written after the root-revocation' {
        $frozenAfter | Should -BeExactly $frozenBefore
    }
}
