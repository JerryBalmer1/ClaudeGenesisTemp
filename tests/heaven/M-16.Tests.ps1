# status: red
# clause: S13 M-16
# spec: S11.2
Describe 'M-16 write attempted after root-revocation' {
    It 'a write after root-revocation is non-zero and writes nothing' {
        $true | Should -Be $false -Because 'frozen chain must refuse writers; module not armed'
    }
}
