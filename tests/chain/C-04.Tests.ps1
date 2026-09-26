# status: red
# spec: S7.5, S3.3
# C-04: revocation marks descendants REVOKED; head revoked -> exit REVOKED.
# Output assumption: Test-GenesisChain prints one line per receipt carrying its hash and status.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-04' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 4

        $middle = Split-ChainRun $run 'middle'
        $null = Add-ChainRevocation $middle $tree[1]
        $middleResult = Test-ChainVerify $middle

        $head = Split-ChainRun $run 'head'
        $null = Add-ChainRevocation $head $tree[3]
        $headResult = Test-ChainVerify $head
    }
    AfterAll { Remove-ChainRun $run }

    It 'the revoked receipt and every descendant print REVOKED' {
        foreach ($h in $tree[1], $tree[2], $tree[3]) {
            $lines = Get-ChainStatusLine $middleResult $h
            $lines | Should -Not -BeNullOrEmpty -Because "receipt $h`n$(Format-ChainResult $middleResult)"
            ($lines -join "`n") | Should -Match '\bREVOKED\b' -Because "receipt $h`n$(Format-ChainResult $middleResult)"
        }
    }

    It 'the ancestor of the revoked receipt is not REVOKED' {
        $lines = Get-ChainStatusLine $middleResult $tree[0]
        $lines | Should -Not -BeNullOrEmpty -Because (Format-ChainResult $middleResult)
        ($lines -join "`n") | Should -Not -Match '\bREVOKED\b' -Because (Format-ChainResult $middleResult)
    }

    It 'revoking the head exits REVOKED' {
        Assert-ChainExit $headResult REVOKED
        (Get-ChainStatusLine $headResult $tree[3]) -join "`n" | Should -Match '\bREVOKED\b'
        (Get-ChainStatusLine $headResult $tree[2]) -join "`n" | Should -Not -Match '\bREVOKED\b'
    }
}
