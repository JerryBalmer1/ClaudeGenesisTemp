# status: red
# clause: S13 M-12
# spec: S6.5
Describe 'M-12 flip one byte in a content blob' {
    It 'corrupting a content/ blob yields HASH_MISMATCH' {
        $true | Should -Be $false -Because 'content bytes are hashed; module not armed'
    }
}
