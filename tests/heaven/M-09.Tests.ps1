# status: red
# clause: S13 M-09
# spec: S7.3
Describe 'M-09 second genesis' {
    It 'a second position-0 receipt yields CHAIN_BREAK' {
        $true | Should -Be $false -Because 'exactly one genesis is allowed; module not armed'
    }
}
