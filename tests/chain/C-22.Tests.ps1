# status: red
# spec: S6.5, S7.1
# C-22: an unresolvable part: default exit 0; -RequireContent -> CONTENT_ABSENT.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-22' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = Add-ChainGenesis $run
        $null = Add-ChainReceipt $run -Context 'part a', 'part b'
        $blob = Join-Path $run.HeavenPath "content/$(Get-ChainTextSha256 'part a')"
        $existed = Test-Path -LiteralPath $blob
        Remove-Item -LiteralPath $blob
        $default = Test-ChainVerify $run
        $required = Test-ChainVerify $run -RequireContent
    }
    AfterAll { Remove-ChainRun $run }

    It 'the part was stored before it was removed' {
        $existed | Should -BeTrue
    }

    It 'receipts-only verification ignores the absent part' {
        Assert-ChainExit $default OK
    }

    It '-RequireContent is CONTENT_ABSENT' {
        Assert-ChainExit $required CONTENT_ABSENT
    }
}
