# status: red
# spec: S6.1, S6.2, S6.3, S6.6
# C-21: the assembler with 0, 1 and 2 parts, a duplicate hash, and CRLF (with a BOM) on disk.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-21' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = Add-ChainGenesis $run
        $utf8 = [Text.UTF8Encoding]::new($false)
        $alpha = New-ChainWorkFile $run -Text 'alpha'
        $beta = New-ChainWorkFile $run -Text 'beta'
        $crlf = New-ChainWorkFile $run -Bytes ([byte[]](0xEF, 0xBB, 0xBF) + $utf8.GetBytes("gamma`r`ndelta"))
        $output = New-ChainWorkFile $run -Bytes ($utf8.GetBytes("out`r`nput"))

        function Add-Assembly([string[]]$Parts) {
            $h = Invoke-ChainWrite $run 'New-GenesisReceipt' @{ ContextPath = $Parts; OutputPath = $output; SigningKeyId = $run.Root.KeyId }
            Read-ChainReceipt (Get-ChainReceiptPath $run $h)
        }
        $zero = Add-Assembly @()
        $one = Add-Assembly @($alpha)
        $two = Add-Assembly @($alpha, $beta)
        $dup = Add-Assembly @($alpha, $alpha)
        $bom = Add-Assembly @($crlf)
        $verify = Test-ChainVerify $run
        $verifyContent = Test-ChainVerify $run -RequireContent
    }
    AfterAll { Remove-ChainRun $run }

    It '0 parts: prompt_context is empty and prompt_hash is SHA-256 of empty' {
        @($zero.prompt_context).Count | Should -Be 0
        $zero.prompt_hash | Should -BeExactly $ChainEmptyHash
    }

    It '1 part: its bytes, no LF added' {
        @($one.prompt_context) -join ',' | Should -BeExactly (Get-ChainTextSha256 'alpha')
        $one.prompt_hash | Should -BeExactly (Get-ChainTextSha256 'alpha')
    }

    It '2 parts: argv order, one LF between, none after' {
        @($two.prompt_context) -join ',' | Should -BeExactly ((Get-ChainTextSha256 'alpha') + ',' + (Get-ChainTextSha256 'beta'))
        $two.prompt_hash | Should -BeExactly (Get-ChainTextSha256 "alpha`nbeta")
    }

    It 'a duplicate part is listed twice and assembled twice' {
        @($dup.prompt_context) -join ',' | Should -BeExactly ((Get-ChainTextSha256 'alpha') + ',' + (Get-ChainTextSha256 'alpha'))
        $dup.prompt_hash | Should -BeExactly (Get-ChainTextSha256 "alpha`nalpha")
    }

    It 'CRLF with a BOM on disk is hashed and stored as UTF-8, no BOM, LF' {
        $h = Get-ChainTextSha256 "gamma`ndelta"
        @($bom.prompt_context) -join ',' | Should -BeExactly $h
        $bom.prompt_hash | Should -BeExactly $h
        $stored = Join-Path $run.HeavenPath "content/$h"
        Test-Path -LiteralPath $stored | Should -BeTrue
        Get-ChainSha256 ([IO.File]::ReadAllBytes($stored)) | Should -BeExactly $h
    }

    It 'the output is normalized before output_hash and stored' {
        $h = Get-ChainTextSha256 "out`nput"
        $zero.output_hash | Should -BeExactly $h
        Test-Path -LiteralPath (Join-Path $run.HeavenPath "content/$h") | Should -BeTrue
    }

    It 'every part is stored in content/ under its hash' {
        foreach ($text in 'alpha', 'beta') {
            Test-Path -LiteralPath (Join-Path $run.HeavenPath "content/$(Get-ChainTextSha256 $text)") | Should -BeTrue
        }
    }

    It 'the chain verifies, with and without -RequireContent' {
        Assert-ChainExit $verify OK
        Assert-ChainExit $verifyContent OK
    }
}
