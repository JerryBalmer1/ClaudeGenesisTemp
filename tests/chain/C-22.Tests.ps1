# status: red
# spec: S6.5, S7.1
# C-22: an unresolvable context part: default verify exits 0; -RequireContent -> CONTENT_ABSENT.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-22' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = Add-HarnessGenesis $run
        $null = Add-HarnessReceipt $run -Context 'alpha' -Output 'out'
        $blob = Join-Path $run.Heaven ('content/' + (Get-HarnessTextSha 'alpha'))
        $present = Test-Path -LiteralPath $blob
        Remove-Item -LiteralPath $blob -ErrorAction Ignore
        $default = Test-HarnessChain $run
        $required = Test-HarnessChain $run -RequireContent
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the writer stored the part' {
        $present | Should -BeTrue
    }

    It 'default verify ignores the absent part' {
        Assert-HarnessExit $default OK
    }

    It '-RequireContent -> CONTENT_ABSENT' {
        Assert-HarnessExit $required CONTENT_ABSENT
    }
}
