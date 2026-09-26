# status: red
# clause: S13 M-17
# spec: S3.6
Describe 'M-17 attributed_to copied into first output line' {
    It 'copying attributed_to into the first output line fails C-28' {
        $true | Should -Be $false -Because 'first line is provenance bytes only; module not armed'
    }
}
