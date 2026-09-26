# status: red
# clause: S13 M-11
# spec: S3.2
Describe 'M-11 chain_position as 3.0' {
    It 'rewrite+rename with fractional chain_position yields SCHEMA' {
        $true | Should -Be $false -Because 'chain_position must be an integer; module not armed'
    }
}
