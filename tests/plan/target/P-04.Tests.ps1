# clause: B1.3
# P-04: Genesis.psm1 is Set-StrictMode, $ErrorActionPreference, dot-source Private/ then Public/,
# Export-ModuleMember from the manifest. Nothing else.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'src/Genesis/Genesis.psm1'), [ref]$tokens, [ref]$errors)
    $statements = @($ast.EndBlock.Statements)

    function Get-OnlyCommand($statement) {
        if ($statement -isnot [Management.Automation.Language.PipelineAst]) { return $null }
        if ($statement.PipelineElements.Count -ne 1) { return $null }
        $statement.PipelineElements[0] -as [Management.Automation.Language.CommandAst]
    }

    function Test-DotSourceLoop($statement, [string]$folder) {
        if ($statement -isnot [Management.Automation.Language.ForEachStatementAst]) { return $false }
        if ($statement.Condition.Extent.Text -notmatch "'$folder'") { return $false }
        $body = @($statement.Body.Statements)
        if ($body.Count -ne 1) { return $false }
        $command = Get-OnlyCommand $body[0]
        [bool]$command -and $command.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Dot
    }
}

Describe 'P-04' {
    It 'parses without errors' {
        $errors | Should -BeNullOrEmpty
    }

    It 'has no param, begin, process, or function definitions' {
        $ast.ParamBlock | Should -BeNullOrEmpty
        $ast.BeginBlock | Should -BeNullOrEmpty
        $ast.ProcessBlock | Should -BeNullOrEmpty
        $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | Should -BeNullOrEmpty
    }

    It 'has exactly five statements' {
        $statements.Count | Should -Be 5
    }

    It 'statement 1 is Set-StrictMode' {
        (Get-OnlyCommand $statements[0]).GetCommandName() | Should -Be 'Set-StrictMode'
    }

    It 'statement 2 assigns $ErrorActionPreference' {
        $statements[1] | Should -BeOfType ([Management.Automation.Language.AssignmentStatementAst])
        $statements[1].Left.VariablePath.UserPath | Should -Be 'ErrorActionPreference'
    }

    It 'statement 3 dot-sources Private/' {
        Test-DotSourceLoop $statements[2] 'Private' | Should -BeTrue
    }

    It 'statement 4 dot-sources Public/' {
        Test-DotSourceLoop $statements[3] 'Public' | Should -BeTrue
    }

    It 'statement 5 is Export-ModuleMember reading the manifest' {
        (Get-OnlyCommand $statements[4]).GetCommandName() | Should -Be 'Export-ModuleMember'
        $statements[4].Extent.Text | Should -Match 'Genesis\.psd1'
    }
}
