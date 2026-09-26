# status: red
# clause: S13 M-02b
# spec: S7.2
Describe 'M-02b canonical field change, rename, old signature' {
    It 'rewrite+rename with stale signature yields SIG_FAIL' {
        $true | Should -Be $false -Because 'canonical mutation must break the signature; module not armed'
    }
}
