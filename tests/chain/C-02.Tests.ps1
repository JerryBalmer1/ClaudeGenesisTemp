# status: red
# spec: S2.1, S7.2
# C-02: verify from a renamed top folder.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-02' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = New-ChainTree $run 3
        $renamed = Join-Path $run.Dir 'renamed-top-folder'
        Rename-Item -LiteralPath $run.HeavenPath -NewName (Split-Path -Leaf $renamed)
        $result = Test-ChainVerify $run -HeavenPath $renamed
    }
    AfterAll { Remove-ChainRun $run }

    It 'the renamed Heaven verifies' {
        Test-Path -LiteralPath $run.HeavenPath | Should -BeFalse
        Assert-ChainExit $result OK
    }
}
