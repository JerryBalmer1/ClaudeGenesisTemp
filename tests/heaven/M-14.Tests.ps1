# status: red
# clause: S13 M-14
# spec: S3.4
Describe 'M-14 actor.kind system' {
    It 'rewrite+rename with actor.kind system yields ACTOR_ILLEGAL' {
        $true | Should -Be $false -Because 'actor.kind enum is closed; module not armed'
    }
}
