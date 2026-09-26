# status: red
# clause: S13 M-06
# spec: S7.3
Describe 'M-06 drop a middle receipt' {
    It 'dropping a middle receipt yields CHAIN_BREAK' {
        $true | Should -Be $false -Because 'parent walk must be contiguous; module not armed'
    }
}
