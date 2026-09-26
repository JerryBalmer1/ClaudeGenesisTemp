# status: red
# clause: S13 M-04
# spec: S2.3
Describe 'M-04 rename one receipt' {
    It 'renaming a receipt yields NAME_MISMATCH' {
        $true | Should -Be $false -Because 'filename must equal payload hash; module not armed'
    }
}
