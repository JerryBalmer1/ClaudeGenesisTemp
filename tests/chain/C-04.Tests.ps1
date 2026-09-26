# status: red
# spec: S7.5, S3.3, S14
# C-04: revocation marks the revoked receipt and its descendants REVOKED; head revoked -> exit REVOKED.
# Per S14 step 9 the revocation receipt itself is not among the descendants it revokes: with it as head the
# chain exits 0. A receipt appended after it descends from the revoked one, so the head is revoked.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-04' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 4
        $revocation = Invoke-HarnessWrite $run 'Add-GenesisRevocation' @{ Revokes = $tree[2]; SigningKeyId = $run.Root.KeyId }
        $headClean = Test-HarnessChain $run
        $later = Add-HarnessReceipt $run -Context 'after revocation' -Output 'after revocation'
        $headRevoked = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the revocation names the revoked receipt' {
        (Read-HarnessReceipt $run $revocation).revokes | Should -BeExactly $tree[2]
    }

    It 'with the revocation as head, exit 0' {
        Assert-HarnessExit $headClean OK
    }

    It 'the revoked receipt and its descendant print REVOKED' {
        foreach ($h in $tree[2], $tree[3]) {
            (Get-HarnessLine $headClean $h) -join "`n" | Should -Match '\bREVOKED\b' -Because (Format-HarnessResult $headClean)
        }
    }

    It 'ancestors of the revoked receipt are not REVOKED' {
        foreach ($h in $tree[0], $tree[1]) {
            (Get-HarnessLine $headClean $h) -join "`n" | Should -Not -Match '\bREVOKED\b'
        }
    }

    It 'a head that descends from the revoked receipt exits REVOKED' {
        $later | Should -Not -BeNullOrEmpty
        Assert-HarnessExit $headRevoked REVOKED
    }
}
