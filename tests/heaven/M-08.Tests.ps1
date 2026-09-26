# status: red
# clause: S13 M-08
# spec: S2.2
Describe 'M-08 plant a subdirectory in receipts' {
    It 'a subdirectory in receipts/ yields NAME_MISMATCH' {
        $true | Should -Be $false -Because 'receipts/ must be flat; module not armed'
    }
}
