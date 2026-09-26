# status: red
# clause: S13 M-13
# spec: S6.5
Describe 'M-13 delete a content blob' {
    It 'deleting a content blob: default 0, -RequireContent -> CONTENT_ABSENT' {
        $true | Should -Be $false -Because 'absent content handling not implemented; module not armed'
    }
}
