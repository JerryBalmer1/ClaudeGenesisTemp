# clause: B0.4
# P-01: nothing under src/ or tests/ references the moved tree.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $needles = @(('leg' + 'acy/'), ('leg' + 'acy\'))
}

Describe 'P-01' {
    It 'no file under src/ or tests/ references the moved tree' {
        $hits = foreach ($dir in 'src', 'tests') {
            Get-ChildItem -Path (Join-Path $root $dir) -Recurse -File -Force | Where-Object {
                $text = [IO.File]::ReadAllText($_.FullName)
                @($needles | Where-Object { $text.Contains($_, [StringComparison]::OrdinalIgnoreCase) }).Count
            } | ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName) }
        }
        $hits | Should -BeNullOrEmpty
    }
}
