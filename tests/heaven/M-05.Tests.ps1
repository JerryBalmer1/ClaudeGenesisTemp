# status: red
# clause: S13 M-05
# spec: S2.3
Describe 'M-05 uppercase one filename' {
    It 'uppercasing a receipt filename yields NAME_MISMATCH' {
        $true | Should -Be $false -Because 'filenames are lowercase hex; module not armed'
    }
}
