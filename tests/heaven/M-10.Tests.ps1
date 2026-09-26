# status: red
# clause: S13 M-10
# spec: S3.2
Describe 'M-10 parent_hash empty at position 3' {
    It 'rewrite+rename with empty parent_hash at position 3 yields SCHEMA' {
        $true | Should -Be $false -Because 'non-genesis receipts require a parent; module not armed'
    }
}
