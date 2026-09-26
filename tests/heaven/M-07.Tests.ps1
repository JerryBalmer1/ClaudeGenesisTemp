# status: red
# clause: S13 M-07
# spec: S2.2
Describe 'M-07 plant notes.txt in receipts' {
    It 'a non-receipt file in receipts/ yields SCHEMA' {
        $true | Should -Be $false -Because 'receipts/ accepts only receipts; module not armed'
    }
}
