# status: red
# spec: S1.9
# C-32: Get-GenesisActor prints root, successor or unknown after the banner, and nothing else, across a
# genesis naming succ1 and one amendment replacing it with succ2.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-32' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = Add-ChainGenesis $run
        $beforeAmendment = Split-ChainRun $run 'before'
        $null = Add-ChainAmendment $run
        $stranger = Get-ChainTextSha256 'no such key'

        function Get-Actor($Run, [string]$Fingerprint) {
            Invoke-Genesis -Run $Run -Command 'Get-GenesisActor' -Parameters @{ Fingerprint = $Fingerprint }
        }
        $cases = [ordered]@{
            'root before the amendment'           = @((Get-Actor $beforeAmendment $run.Root.Fingerprint), 'root')
            'succ1 before the amendment'          = @((Get-Actor $beforeAmendment $run.Succ1.Fingerprint), 'successor')
            'succ2 before the amendment'          = @((Get-Actor $beforeAmendment $run.Succ2.Fingerprint), 'unknown')
            'root after the amendment'            = @((Get-Actor $run $run.Root.Fingerprint), 'root')
            'succ1 after the amendment'           = @((Get-Actor $run $run.Succ1.Fingerprint), 'unknown')
            'succ2 after the amendment'           = @((Get-Actor $run $run.Succ2.Fingerprint), 'successor')
            'a stranger fingerprint'              = @((Get-Actor $run $stranger), 'unknown')
        }
    }
    AfterAll { Remove-ChainRun $run }

    It '<_>' -ForEach @('root before the amendment', 'succ1 before the amendment', 'succ2 before the amendment', 'root after the amendment', 'succ1 after the amendment', 'succ2 after the amendment', 'a stranger fingerprint') {
        $r, $expected = $cases[$_]
        Assert-ChainExit $r OK
        $r.Lines.Count | Should -Be 2 -Because (Format-ChainResult $r)
        $r.Lines[1] | Should -BeExactly $expected
    }
}
