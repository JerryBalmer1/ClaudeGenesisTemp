# status: red
# clause: S13 M-02
# spec: S7.2
Describe 'M-02 raw byte flip inside position-1 signature' {
    It 'flipping one byte in a position-1 signature value yields SIG_FAIL' {
        $true | Should -Be $false -Because 'raw signature mutation must be detected; module not armed'
    }
}
