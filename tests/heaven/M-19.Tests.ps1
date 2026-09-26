# status: red
# clause: S13 M-19
# spec: S7.7
Describe 'M-19 unresolved discrepancy' {
    It 'an unresolved discrepancy yields DISCREPANCY' {
        $true | Should -Be $false -Because 'discrepancies must be resolved; module not armed'
    }
}
