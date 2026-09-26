# status: red
# clause: S13 M-15
# spec: S8.2
Describe 'M-15 root-revocation signed by root' {
    It 'a root-revocation signed by the root key yields SIG_FAIL' {
        $true | Should -Be $false -Because 'root-revocation must be successor-signed; module not armed'
    }
}
