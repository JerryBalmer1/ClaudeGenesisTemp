# status: red
# clause: S13 M-03
# spec: S7.2
Describe 'M-03 raw byte flip inside genesis signature' {
    It 'flipping one byte in genesis signature value yields SIG_FAIL' {
        $true | Should -Be $false -Because 'genesis signature mutation must be caught; module not armed'
    }
}
