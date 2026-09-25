# clause: B8.1
# P-16: ci.yml runs ./build.ps1 bare, on windows-latest and ubuntu-latest, with no env override.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $yml = [IO.File]::ReadAllText((Join-Path $root '.github/workflows/ci.yml')) -replace "`r`n", "`n"
    $buildJob = [regex]::Match($yml, '(?ms)^  build:\n(.*?)(?=^  \S|\z)').Groups[1].Value
}

Describe 'P-16' {
    It 'has a build job' {
        $buildJob | Should -Not -BeNullOrEmpty
    }

    It 'the build job runs ./build.ps1 with no arguments' {
        $buildJob | Should -Match '(?m)^\s+run:\s*\./build\.ps1\s*$'
        $buildJob | Should -Not -Match '(?m)^\s+run:\s*\./build\.ps1\s+\S'
    }

    It 'the build job runs on <_>' -ForEach @('windows-latest', 'ubuntu-latest') {
        $buildJob | Should -Match ([regex]::Escape($_))
    }

    It 'the build job sets no environment' {
        $buildJob | Should -Not -Match '(?m)^\s+env:'
    }
}
