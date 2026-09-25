# clause: B10.1
# P-22: audit/ exists, is tracked, is not ignored, and is not in the payload.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

Describe 'P-22' {
    It 'audit/<_>/ exists' -ForEach @('inbox', 'receipts', 'content') {
        Join-Path $root "audit/$_" | Should -Exist
    }

    It 'audit/ is tracked' {
        git -C $root ls-files -- audit | Should -Not -BeNullOrEmpty
    }

    It 'audit/ is not ignored' {
        $PSNativeCommandUseErrorActionPreference = $false
        git -C $root check-ignore -q --no-index -- audit/inbox/.gitkeep
        $LASTEXITCODE | Should -Be 1
    }

    It 'audit/ is not in the committed payload manifest' {
        $manifest = Get-Content -LiteralPath (Join-Path $root 'payload.manifest.json') -Raw | ConvertFrom-Json
        @($manifest.files | Where-Object { $_.path -like 'audit/*' }) | Should -BeNullOrEmpty
    }

    It 'audit/ is not in out/payload/' {
        Join-Path $root 'out/payload/audit' | Should -Not -Exist
    }
}
