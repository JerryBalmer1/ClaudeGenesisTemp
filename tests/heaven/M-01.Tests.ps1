# status: red
# clause: S13 M-01
# spec: S7.2
Describe 'M-01 temptation verifier skips signature at position 0' {
    It 'shipping Test-GenesisChain rejects the flipped genesis (C-08b)' {
        # Temptation module loaded by explicit path from tests/fixtures/temptation/
        # verifies a genesis-flipped tree clean; shipping verifier must print SIG_FAIL.
        $true | Should -Be $false -Because 'temptation verifier must not ship; M-01 expects SIG_FAIL from shipping Test-GenesisChain'
    }
}
