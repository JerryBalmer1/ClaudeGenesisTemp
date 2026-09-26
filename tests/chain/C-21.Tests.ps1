# status: red
# spec: S6.1, S6.2, S6.3, S6.6, S3.2
# C-21: the assembler with 0, 1 and 2 parts, a duplicated part, and a part stored CRLF with a BOM.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')

    function Add-Assembled([string[]]$Paths, [string]$OutputPath) {
        Invoke-HarnessWrite $run 'New-GenesisReceipt' @{ ContextPath = $Paths; OutputPath = $OutputPath; SigningKeyId = $run.Root.KeyId }
    }
}

Describe 'C-21' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = Add-HarnessGenesis $run
        $alpha = New-HarnessFile $run -Text 'alpha'
        $beta = New-HarnessFile $run -Text 'beta'
        $crlf = New-HarnessFile $run -Bytes ([byte[]](0xEF, 0xBB, 0xBF) + [Text.Encoding]::ASCII.GetBytes("one`r`ntwo"))
        $outCrlf = New-HarnessFile $run -Bytes ([Text.Encoding]::ASCII.GetBytes("out`r`n"))

        $zero = Read-HarnessReceipt $run (Add-Assembled @() (New-HarnessFile $run -Text 'zero out'))
        $one = Read-HarnessReceipt $run (Add-Assembled @($alpha) (New-HarnessFile $run -Text 'one out'))
        $two = Read-HarnessReceipt $run (Add-Assembled @($alpha, $beta) (New-HarnessFile $run -Text 'two out'))
        $dup = Read-HarnessReceipt $run (Add-Assembled @($alpha, $alpha) (New-HarnessFile $run -Text 'dup out'))
        $norm = Read-HarnessReceipt $run (Add-Assembled @($crlf) $outCrlf)
        $chain = Test-HarnessChain $run -RequireContent

        $hA = Get-HarnessTextSha 'alpha'
        $hB = Get-HarnessTextSha 'beta'
        $hN = Get-HarnessTextSha "one`ntwo"
    }
    AfterAll { Remove-HarnessRun $run }

    It '0 parts: empty context, prompt_hash = SHA-256("")' {
        @($zero.prompt_context).Count | Should -Be 0
        $zero.prompt_hash | Should -BeExactly $HarnessEmpty
    }

    It '1 part: its bytes, no trailing LF' {
        @($one.prompt_context) -join ',' | Should -BeExactly $hA
        $one.prompt_hash | Should -BeExactly $hA
    }

    It '2 parts: argv order, one LF between, none after' {
        @($two.prompt_context) -join ',' | Should -BeExactly "$hA,$hB"
        $two.prompt_hash | Should -BeExactly (Get-HarnessTextSha "alpha`nbeta")
    }

    It 'a duplicated part is kept twice' {
        @($dup.prompt_context) -join ',' | Should -BeExactly "$hA,$hA"
        $dup.prompt_hash | Should -BeExactly (Get-HarnessTextSha "alpha`nalpha")
    }

    It 'CRLF and BOM on disk are normalized before hashing' {
        @($norm.prompt_context) -join ',' | Should -BeExactly $hN
        $norm.prompt_hash | Should -BeExactly $hN
        $norm.output_hash | Should -BeExactly (Get-HarnessTextSha "out`n")
    }

    It 'content/ stores the normalized bytes under their hash' {
        foreach ($pair in @(@($hN, "one`ntwo"), @((Get-HarnessTextSha "out`n"), "out`n"), @($hA, 'alpha'))) {
            $path = Join-Path $run.Heaven "content/$($pair[0])"
            Test-Path -LiteralPath $path | Should -BeTrue
            [Convert]::ToHexString([IO.File]::ReadAllBytes($path)) | Should -BeExactly ([Convert]::ToHexString($HarnessUtf8.GetBytes($pair[1])))
        }
    }

    It 'the chain verifies with content required' {
        Assert-HarnessExit $chain OK
    }
}
