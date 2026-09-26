# status: red
# clause: S13 M-18
# spec: S7.3
Describe 'M-18 second receipt with existing parent_hash' {
    It 'a second receipt sharing a parent_hash yields CHAIN_BREAK' {
        $true | Should -Be $false -Because 'one parent per child; module not armed'
    }
}
