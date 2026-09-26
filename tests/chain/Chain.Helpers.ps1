# Chain test harness (S12). Dot-sourced by tests/chain/C-*.ps1; not itself a test.
#
# Every module command runs in a child pwsh that imports src/Genesis/Genesis.psd1 by explicit path, with stdin
# redirected (no TTY) and the working directory set to an empty folder that is neither the Heaven nor the
# GnupgHome (S1.3). Stdout is captured as raw bytes (S3.6); line 2 of a non-zero exit is the class (S7.8).
#
# Keys are generated here, never by the module (S1.4, B5.2, B5.3). Signing, export and verification use the
# S4.2 argv. Receipt rewrites use ConvertTo-ChainCanonicalJson, a test oracle for the S3 value domain
# (objects, arrays, strings, integers); it is not the module's JCS and does not load it.

$script:ChainRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$script:ChainModule = Join-Path $script:ChainRoot 'src/Genesis/Genesis.psd1'
$script:ChainBanner = [byte[]](0x70, 0x72, 0x6F, 0x76, 0x65, 0x6E, 0x61, 0x6E, 0x63, 0x65, 0x20, 0xE2, 0x89, 0xA0, 0x20, 0x74, 0x72, 0x75, 0x74, 0x68)
$script:ChainEmptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$script:ChainTimeoutMs = 300000

function Get-ChainSha256([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Get-ChainTextSha256([string]$Text) {
    Get-ChainSha256 ([Text.UTF8Encoding]::new($false).GetBytes($Text))
}

function Write-ChainBytes([string]$Path, [byte[]]$Bytes) {
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

function Write-ChainText([string]$Path, [string]$Text) {
    Write-ChainBytes $Path ([Text.UTF8Encoding]::new($false).GetBytes($Text))
}

# ---------------------------------------------------------------------------------------------------------
# gpg (S4.2, B5.1). Real gpg >= tools.lock.json gpg.MinVersion, first on PATH, as the module will find it.

function Get-ChainGpg {
    if (-not (Get-Variable -Name ChainGpg -Scope Script -ErrorAction Ignore)) {
        $cmd = Get-Command -Name gpg -CommandType Application -ErrorAction Ignore | Select-Object -First 1
        if (-not $cmd) { throw 'chain harness: gpg not found on PATH (B5.1)' }
        $lock = Get-Content -LiteralPath (Join-Path $script:ChainRoot 'tools.lock.json') -Raw | ConvertFrom-Json -AsHashtable
        $line = @(& $cmd.Source --version)[0]
        if ($line -notmatch '(\d+\.\d+(\.\d+)?)' -or [version]$Matches[1] -lt [version]$lock.gpg.MinVersion) {
            throw "chain harness: '$line' at $($cmd.Source) is below gpg $($lock.gpg.MinVersion) (S4.2)"
        }
        $script:ChainGpg = $cmd.Source
    }
    $script:ChainGpg
}

function Invoke-ChainGpg {
    param([string[]]$Argv, [string]$Stdin)
    $gpg = Get-ChainGpg
    $PSNativeCommandUseErrorActionPreference = $false
    $out = if ($PSBoundParameters.ContainsKey('Stdin')) { $Stdin | & $gpg @Argv 2>&1 } else { & $gpg @Argv 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "chain harness: gpg $($Argv -join ' ') exited $LASTEXITCODE`n$($out -join "`n")" }
    $out
}

function New-ChainKey {
    # B5.2 batch. -Passphrase makes a protected key with a comment that is not the synthetic one (C-12).
    param([string]$GnupgHome, [string]$KeyDir, [string]$Name, [string]$Passphrase)
    $protected = [bool]$Passphrase
    $batch = @(
        'Key-Type: EdDSA'
        'Key-Curve: Ed25519'
        'Name-Real: GENESIS SYNTHETIC'
        if ($protected) { 'Name-Comment: GENESIS-CHAIN-TEST-PROTECTED' } else { 'Name-Comment: GENESIS-SYNTHETIC-DO-NOT-TRUST' }
        'Name-Email: synthetic@invalid'
        'Expire-Date: 1d'
        if ($protected) { "Passphrase: $Passphrase" } else { '%no-protection' }
        '%commit'
    ) -join "`n"
    $batchPath = Join-Path $KeyDir "$Name.batch"
    Write-ChainText $batchPath "$batch`n"

    $before = @(Get-ChainSecretFingerprint $GnupgHome)
    $null = Invoke-ChainGpg -Argv @('--batch', '--no-tty', '--homedir', $GnupgHome, '--pinentry-mode', 'loopback', '--generate-key', $batchPath)
    $new = @(Get-ChainSecretFingerprint $GnupgHome | Where-Object { $_ -notin $before })
    if ($new.Count -ne 1) { throw "chain harness: expected one new key for $Name, found $($new.Count)" }
    Remove-Item -LiteralPath $batchPath

    # S4.2 export argv, exactly.
    $out = Join-Path $KeyDir "$Name.bin"
    $null = Invoke-ChainGpg -Argv @('--batch', '--no-tty', '--homedir', $GnupgHome, '--export', '--export-options', 'export-minimal', '--output', $out, $new[0])
    $bytes = [IO.File]::ReadAllBytes($out)
    [pscustomobject]@{
        Name            = $Name
        KeyId           = $new[0]
        PublicKeyPath   = $out
        PublicKeyBase64 = [Convert]::ToBase64String($bytes)
        Fingerprint     = Get-ChainSha256 $bytes   # S4.3, not gpg's fingerprint
        Passphrase      = $Passphrase
    }
}

function Get-ChainSecretFingerprint([string]$GnupgHome) {
    $PSNativeCommandUseErrorActionPreference = $false
    $lines = @(& (Get-ChainGpg) --batch --no-tty --homedir $GnupgHome --list-secret-keys --with-colons 2>$null)
    $primary = $false
    foreach ($l in $lines) {
        if ($l -like 'sec:*') { $primary = $true; continue }
        if ($l -like 'ssb:*') { $primary = $false; continue }
        if ($primary -and $l -like 'fpr:*') { ($l -split ':')[9]; $primary = $false }
    }
}

function New-ChainSignature {
    # S4.2 sign argv: synthetic unprotected key, or protected key with the passphrase on fd 0.
    param([string]$GnupgHome, $Key, [byte[]]$Payload, [string]$ScratchDir)
    $id = [guid]::NewGuid().ToString('N')
    $payloadFile = Join-Path $ScratchDir "$id.payload"
    $sigFile = Join-Path $ScratchDir "$id.sig"
    Write-ChainBytes $payloadFile $Payload
    try {
        if ($Key.Passphrase) {
            $null = Invoke-ChainGpg -Stdin $Key.Passphrase -Argv @('--batch', '--no-tty', '--homedir', $GnupgHome, '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--local-user', $Key.KeyId, '--digest-algo', 'SHA256', '--detach-sign', '--output', $sigFile, $payloadFile)
        }
        else {
            $null = Invoke-ChainGpg -Argv @('--batch', '--no-tty', '--homedir', $GnupgHome, '--pinentry-mode', 'loopback', '--local-user', $Key.KeyId, '--digest-algo', 'SHA256', '--detach-sign', '--output', $sigFile, $payloadFile)
        }
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sigFile))
    }
    finally {
        Remove-Item -LiteralPath $payloadFile, $sigFile -Force -ErrorAction Ignore
    }
}

function Test-ChainSignature {
    # S4.2 verify argv against a fresh temp homedir, deleted afterwards. True when gpg exits 0.
    param([byte[]]$PublicKey, [byte[]]$Payload, [string]$Signature, [string]$ScratchDir)
    $tempHome = Join-Path $ScratchDir ('verify-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $tempHome
    try {
        $keyFile = Join-Path $tempHome 'key.bin'
        $sigFile = Join-Path $tempHome 'payload.sig'
        $payloadFile = Join-Path $tempHome 'payload'
        Write-ChainBytes $keyFile $PublicKey
        Write-ChainBytes $sigFile ([Convert]::FromBase64String($Signature))
        Write-ChainBytes $payloadFile $Payload
        $keyring = "$tempHome/keyring.kbx"
        $null = Invoke-ChainGpg -Argv @('--batch', '--no-tty', '--homedir', $tempHome, '--no-default-keyring', '--keyring', $keyring, '--trust-model', 'always', '--import', $keyFile)
        $PSNativeCommandUseErrorActionPreference = $false
        $null = & (Get-ChainGpg) --batch --no-tty --homedir $tempHome --no-default-keyring --keyring $keyring --trust-model always --verify $sigFile $payloadFile 2>&1
        $LASTEXITCODE -eq 0
    }
    finally {
        Stop-ChainGpgAgent $tempHome
        Remove-Item -LiteralPath $tempHome -Recurse -Force -ErrorAction Ignore
    }
}

function Stop-ChainGpgAgent([string]$GnupgHome) {
    if (-not $GnupgHome -or -not (Test-Path -LiteralPath $GnupgHome)) { return }
    $gpgconf = Join-Path (Split-Path -Parent (Get-ChainGpg)) ($IsWindows ? 'gpgconf.exe' : 'gpgconf')
    if (-not (Test-Path -LiteralPath $gpgconf)) { $gpgconf = 'gpgconf' }
    $PSNativeCommandUseErrorActionPreference = $false
    $null = & $gpgconf --homedir $GnupgHome --kill all 2>&1
}

# ---------------------------------------------------------------------------------------------------------
# Canonical bytes oracle (S5.1). RFC 8785 restricted to the receipt value domain; a fraction throws (S5.3).

function ConvertTo-ChainJsonString([string]$Text) {
    $sb = [Text.StringBuilder]::new('"')
    foreach ($c in $Text.ToCharArray()) {
        switch ([int]$c) {
            0x22 { $null = $sb.Append('\"') }
            0x5C { $null = $sb.Append('\\') }
            0x08 { $null = $sb.Append('\b') }
            0x0C { $null = $sb.Append('\f') }
            0x0A { $null = $sb.Append('\n') }
            0x0D { $null = $sb.Append('\r') }
            0x09 { $null = $sb.Append('\t') }
            default {
                if ([int]$c -lt 0x20) { $null = $sb.Append('\u').Append(([int]$c).ToString('x4')) }
                else { $null = $sb.Append($c) }
            }
        }
    }
    $sb.Append('"').ToString()
}

function ConvertTo-ChainCanonicalJson($Value) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $Value ? 'true' : 'false' }
    if ($Value -is [string]) { return ConvertTo-ChainJsonString $Value }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [bigint]) { return $Value.ToString([Globalization.CultureInfo]::InvariantCulture) }
    if ($Value -is [Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys)
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        return '{' + (@(foreach ($k in $keys) { (ConvertTo-ChainJsonString $k) + ':' + (ConvertTo-ChainCanonicalJson $Value[$k]) }) -join ',') + '}'
    }
    if ($Value -is [Collections.IEnumerable]) {
        return '[' + (@(foreach ($v in $Value) { ConvertTo-ChainCanonicalJson $v }) -join ',') + ']'
    }
    throw "chain harness: no canonical form for [$($Value.GetType().FullName)] (S5.3)"
}

function Get-ChainPayloadBytes($Receipt) {
    $copy = [ordered]@{}
    foreach ($k in $Receipt.Keys) { if ($k -cne 'signature') { $copy[$k] = $Receipt[$k] } }
    [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-ChainCanonicalJson $copy))
}

# ---------------------------------------------------------------------------------------------------------
# Runs: one GnupgHome with three synthetic keys, one Heaven, one work folder for context/output files.

function New-ChainRun {
    param([string]$Parent = $TestDrive)
    $dir = Join-Path $Parent ('run-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $run = [pscustomobject]@{
        Dir        = $dir
        GnupgHome  = Join-Path $dir 'gnupg'
        HeavenPath = Join-Path $dir 'heaven'
        Work       = Join-Path $dir 'work'
        Keys       = Join-Path $dir 'keys'
        Cwd        = Join-Path $dir 'cwd'
        Scratch    = Join-Path $dir 'scratch'
        Root       = $null
        Succ1      = $null
        Succ2      = $null
        Counter    = 0
    }
    foreach ($p in $run.GnupgHome, $run.Work, $run.Keys, $run.Cwd, $run.Scratch) { $null = New-Item -ItemType Directory -Path $p -Force }
    New-ChainHeaven $run.HeavenPath
    $run.Root = New-ChainKey -GnupgHome $run.GnupgHome -KeyDir $run.Keys -Name 'root'
    $run.Succ1 = New-ChainKey -GnupgHome $run.GnupgHome -KeyDir $run.Keys -Name 'succ1'
    $run.Succ2 = New-ChainKey -GnupgHome $run.GnupgHome -KeyDir $run.Keys -Name 'succ2'
    $run
}

function Remove-ChainRun($Run) {
    if ($Run) { Stop-ChainGpgAgent $Run.GnupgHome }
}

function New-ChainHeaven([string]$Path) {
    # S2.1: a directory holding receipts/ and content/ and nothing else.
    $null = New-Item -ItemType Directory -Path (Join-Path $Path 'receipts') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Path 'content') -Force
}

function Copy-ChainHeaven([string]$Source, [string]$Destination) {
    New-ChainHeaven $Destination
    foreach ($sub in 'receipts', 'content') {
        Get-ChildItem -LiteralPath (Join-Path $Source $sub) -Force | Copy-Item -Destination (Join-Path $Destination $sub) -Recurse
    }
}

function Get-ChainReceiptName([string]$HeavenPath) {
    @(Get-ChildItem -LiteralPath (Join-Path $HeavenPath 'receipts') -Force | ForEach-Object Name | Sort-Object)
}

function Get-ChainSnapshot([string]$HeavenPath) {
    # One line per file under receipts/ and content/: relative path, SHA-256, last write (S11.1).
    @(Get-ChildItem -LiteralPath $HeavenPath -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
            '{0} {1} {2}' -f [IO.Path]::GetRelativePath($HeavenPath, $_.FullName).Replace('\', '/'),
            (Get-ChainSha256 ([IO.File]::ReadAllBytes($_.FullName))), $_.LastWriteTimeUtc.Ticks
        }) -join "`n"
}

function New-ChainWorkFile {
    # A context or output file for the assembler (S6). Text is written UTF-8, no BOM, as given.
    param($Run, [string]$Text, [byte[]]$Bytes)
    $Run.Counter++
    $path = Join-Path $Run.Work ('f{0:d3}.txt' -f $Run.Counter)
    if ($PSBoundParameters.ContainsKey('Bytes')) { Write-ChainBytes $path $Bytes } else { Write-ChainText $path $Text }
    $path
}

# ---------------------------------------------------------------------------------------------------------
# Invoking the module.

function Get-ChainRunner {
    $runner = Join-Path $TestDrive 'invoke-genesis.ps1'
    if (-not (Test-Path -LiteralPath $runner)) {
        Write-ChainText $runner (@(
                'param([string]$ModulePath, [string]$CommandName, [string]$ParameterFile)'
                '$ErrorActionPreference = ''Stop'''
                '$PSStyle.OutputRendering = ''PlainText'''
                'Import-Module -Name $ModulePath'
                '$parameters = Get-Content -LiteralPath $ParameterFile -Raw | ConvertFrom-Json -AsHashtable'
                '& $CommandName @parameters'
            ) -join "`n")
    }
    $runner
}

function Invoke-Genesis {
    # -HeavenPath and -GnupgHome come from -Run unless -Parameters names them (S1.3). -Module overrides the
    # module path (C-08). Returns exit code, raw stdout bytes, lines, class (line 2), stderr, and the receipt
    # hashes written to the run's Heaven.
    param($Run, [string]$Command, [hashtable]$Parameters = @{}, [string]$Module = $script:ChainModule, [switch]$NoHeaven)
    $p = [ordered]@{}
    if (-not $NoHeaven) { $p.HeavenPath = $Run.HeavenPath }
    $p.GnupgHome = $Run.GnupgHome
    foreach ($k in $Parameters.Keys) { $p[$k] = $Parameters[$k] }
    $heaven = $p['HeavenPath']

    $paramFile = Join-Path $Run.Scratch ('p-' + [guid]::NewGuid().ToString('N') + '.json')
    Write-ChainText $paramFile (ConvertTo-Json -InputObject $p -Depth 5)
    $before = if ($heaven -and (Test-Path -LiteralPath (Join-Path $heaven 'receipts'))) { Get-ChainReceiptName $heaven } else { @() }

    $psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($a in '-NoProfile', '-NonInteractive', '-File', (Get-ChainRunner), $Module, $Command, $paramFile) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = $Run.Cwd
    $proc = [Diagnostics.Process]::Start($psi)
    try {
        $proc.StandardInput.Close()
        $stdout = [IO.MemoryStream]::new()
        $copy = $proc.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderr = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($script:ChainTimeoutMs)) {
            $proc.Kill($true)
            throw "chain harness: $Command timed out after $($script:ChainTimeoutMs) ms"
        }
        $copy.Wait()
        $bytes = $stdout.ToArray()
        $text = [Text.UTF8Encoding]::new($false).GetString($bytes)
        $lines = [Collections.Generic.List[string]]::new([string[]]($text -split '\r?\n'))
        while ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
        $after = if ($heaven -and (Test-Path -LiteralPath (Join-Path $heaven 'receipts'))) { Get-ChainReceiptName $heaven } else { @() }
        [pscustomobject]@{
            Command  = $Command
            ExitCode = $proc.ExitCode
            Bytes    = $bytes
            Text     = $text
            Lines    = [string[]]$lines
            Class    = if ($lines.Count -ge 2) { $lines[1] } else { $null }
            Stderr   = $stderr.Result
            Written  = @($after | Where-Object { $_ -notin $before } | ForEach-Object { $_ -replace '\.json$' })
        }
    }
    finally {
        $proc.Dispose()
        Remove-Item -LiteralPath $paramFile -Force -ErrorAction Ignore
    }
}

function Format-ChainResult($Result) {
    "$($Result.Command) exited $($Result.ExitCode)`nstdout:`n$($Result.Text)`nstderr:`n$($Result.Stderr)"
}

function Assert-ChainExit {
    # 'OK' means exit 0. Otherwise non-zero with the class name as the second output line (S7.8).
    param($Result, [string]$Class)
    if ($Class -ceq 'OK') {
        $Result.ExitCode | Should -Be 0 -Because (Format-ChainResult $Result)
        return
    }
    $Result.ExitCode | Should -Not -Be 0 -Because (Format-ChainResult $Result)
    $Result.Class | Should -BeExactly $Class -Because (Format-ChainResult $Result)
}

function Get-ChainWritten($Result) {
    # The one receipt a write produced; throws with the command's output when it produced none or several.
    if ($Result.Written.Count -ne 1) {
        throw "chain setup: expected $($Result.Command) to write one receipt, wrote $($Result.Written.Count)`n$(Format-ChainResult $Result)"
    }
    $Result.Written[0]
}

function Invoke-ChainWrite {
    # Setup step: the command must exit 0 and write exactly one receipt; returns its hash.
    param($Run, [string]$Command, [hashtable]$Parameters = @{})
    $r = Invoke-Genesis -Run $Run -Command $Command -Parameters $Parameters
    if ($r.ExitCode -ne 0 -or $r.Written.Count -ne 1) {
        throw "chain setup: expected $Command to exit 0 and write one receipt, wrote $($r.Written.Count)`n$(Format-ChainResult $r)"
    }
    $r.Written[0]
}

# Parameters for each writer, per S14. Get-* returns the hashtable; Add-* runs it as a setup step.

function Get-ChainGenesisParameters($Run, $Successor) {
    if (-not $Successor) { $Successor = $Run.Succ1 }
    @{ RootPublicKey = $Run.Root.PublicKeyPath; SuccessorPublicKey = $Successor.PublicKeyPath; SigningKeyId = $Run.Root.KeyId }
}

function Get-ChainReceiptParameters {
    param($Run, [string[]]$Context = @('context'), [string]$Output = 'output', [string]$AttributedTo)
    $p = @{
        ContextPath  = [string[]]@(foreach ($c in $Context) { New-ChainWorkFile $Run -Text $c })
        OutputPath   = New-ChainWorkFile $Run -Text $Output
        SigningKeyId = $Run.Root.KeyId
    }
    if ($AttributedTo) { $p.AttributedTo = $AttributedTo }
    $p
}

function Get-ChainAmendmentParameters($Run) {
    @{
        SuccessorPublicKey          = $Run.Succ2.PublicKeyPath
        RevokedSuccessorFingerprint = $Run.Succ1.Fingerprint
        Reason                      = 'successor-media-lost'
        SigningKeyId                = $Run.Root.KeyId
    }
}

function Get-ChainDiscrepancyParameters($Run, [string]$Seed = 'discrepancy') {
    @{
        CheckName    = 'HASH_MISMATCH'
        ObservedHash = Get-ChainTextSha256 "$Seed-observed"
        ExpectedHash = Get-ChainTextSha256 "$Seed-expected"
        SubjectId    = Get-ChainTextSha256 "$Seed-subject"
        SigningKeyId = $Run.Root.KeyId
    }
}

function Add-ChainGenesis($Run, $Successor) {
    Invoke-ChainWrite $Run 'New-GenesisRoot' (Get-ChainGenesisParameters $Run $Successor)
}

function Add-ChainReceipt {
    param($Run, [string[]]$Context = @('context'), [string]$Output = 'output', [string]$AttributedTo)
    Invoke-ChainWrite $Run 'New-GenesisReceipt' (Get-ChainReceiptParameters -Run $Run -Context $Context -Output $Output -AttributedTo $AttributedTo)
}

function Add-ChainAmendment($Run) {
    Invoke-ChainWrite $Run 'Add-GenesisAmendment' (Get-ChainAmendmentParameters $Run)
}

function Add-ChainDiscrepancy($Run, [string]$Seed = 'discrepancy') {
    Invoke-ChainWrite $Run 'New-GenesisDiscrepancy' (Get-ChainDiscrepancyParameters $Run $Seed)
}

function Add-ChainResolution($Run, [string]$Discrepancy) {
    Invoke-ChainWrite $Run 'Resolve-GenesisDiscrepancy' @{ Resolves = $Discrepancy; SigningKeyId = $Run.Root.KeyId }
}

function Add-ChainRevocation($Run, [string]$Revokes) {
    Invoke-ChainWrite $Run 'Add-GenesisRevocation' @{ Revokes = $Revokes; SigningKeyId = $Run.Root.KeyId }
}

function Split-ChainRun {
    # A second Heaven over the same keys: a copy of the run's Heaven (or an empty one) in a new folder, and a
    # view of the run pointed at it with its own work folder.
    param($Run, [string]$Name, [switch]$Empty)
    $view = $Run.PSObject.Copy()
    $view.HeavenPath = Join-Path $Run.Dir "heaven-$Name"
    $view.Work = Join-Path $Run.Dir "work-$Name"
    $null = New-Item -ItemType Directory -Path $view.Work -Force
    if ($Empty) { New-ChainHeaven $view.HeavenPath } else { Copy-ChainHeaven $Run.HeavenPath $view.HeavenPath }
    $view
}

function New-ChainTree {
    # Genesis plus ($Receipts - 1) receipts, each with its own context and output. Hashes in chain order.
    param($Run, [int]$Receipts)
    $hashes = [Collections.Generic.List[string]]::new()
    $hashes.Add((Add-ChainGenesis $Run))
    for ($i = 1; $i -lt $Receipts; $i++) { $hashes.Add((Add-ChainReceipt $Run -Context "context $i" -Output "output $i")) }
    , $hashes.ToArray()
}

function Test-ChainVerify {
    param($Run, [string]$HeavenPath, [switch]$RequireContent, [switch]$Verbose)
    $p = @{}
    if ($HeavenPath) { $p.HeavenPath = $HeavenPath }
    if ($RequireContent) { $p.RequireContent = $true }
    if ($Verbose) { $p.Verbose = $true }
    Invoke-Genesis -Run $Run -Command 'Test-GenesisChain' -Parameters $p
}

# ---------------------------------------------------------------------------------------------------------
# Mutating a tree (the S13 conventions, applied by tests).

function Get-ChainReceiptPath($Run, [string]$Hash, [string]$HeavenPath) {
    if (-not $HeavenPath) { $HeavenPath = $Run.HeavenPath }
    Join-Path $HeavenPath "receipts/$Hash.json"
}

function Read-ChainReceipt([string]$Path) {
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Write-ChainReceipt {
    # Writes the receipt as canonical JSON under receipts/<SHA-256 of its payload bytes>.json; returns the hash.
    param([string]$HeavenPath, $Receipt)
    $hash = Get-ChainSha256 (Get-ChainPayloadBytes $Receipt)
    Write-ChainText (Join-Path $HeavenPath "receipts/$hash.json") (ConvertTo-ChainCanonicalJson $Receipt)
    $hash
}

function Edit-ChainReceipt {
    # Rewrite + rename. -SignWith re-signs the new payload with that key; without it the old signature stays.
    param($Run, [string]$Hash, [scriptblock]$Mutate, $SignWith, [string]$HeavenPath)
    if (-not $HeavenPath) { $HeavenPath = $Run.HeavenPath }
    $path = Get-ChainReceiptPath $Run $Hash $HeavenPath
    $receipt = Read-ChainReceipt $path
    Remove-Item -LiteralPath $path
    & $Mutate $receipt
    if ($SignWith) { $receipt.signature = New-ChainSignature -GnupgHome $Run.GnupgHome -Key $SignWith -Payload (Get-ChainPayloadBytes $receipt) -ScratchDir $Run.Scratch }
    Write-ChainReceipt $HeavenPath $receipt
}

function Invoke-ChainSignatureFlip {
    # Raw, no rename: replace one base64 character inside the "signature" value with a different one. The
    # character sits six from the end of the unpadded value, inside the signature MPI; a flip in the unhashed
    # subpackets near the middle can leave a signature gpg still verifies.
    param([string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    $m = [regex]::Match($text, '"signature"\s*:\s*"([A-Za-z0-9+/=]+)"')
    if (-not $m.Success -or $m.Groups[1].Length -lt 16) { throw "chain harness: no signature value in $Path" }
    $at = $m.Groups[1].Index + $m.Groups[1].Value.TrimEnd('=').Length - 6
    $bytes[$at] = if ($bytes[$at] -eq [byte][char]'A') { [byte][char]'B' } else { [byte][char]'A' }
    [IO.File]::WriteAllBytes($Path, $bytes)
}

function New-ChainBody {
    # Common S3.2 fields for a hand-built receipt of any type but `receipt`; no signature.
    param([string]$Type, [string]$Kind = 'root', [string]$Fingerprint, [string]$Parent, [long]$Position)
    [ordered]@{
        receipt_type   = $Type
        actor          = [ordered]@{ kind = $Kind; fingerprint = $Fingerprint }
        prompt_hash    = $script:ChainEmptyHash
        prompt_context = @()
        output_hash    = $script:ChainEmptyHash
        parent_hash    = $Parent
        chain_position = $Position
        claimed_time   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
}

function Get-ChainLaterLine($Result) {
    # Every output line after the first. The Chain task bans any -Skip parameter in tests/chain/ (S12).
    if ($Result.Lines.Count -gt 1) { $Result.Lines[1..($Result.Lines.Count - 1)] }
}

function Get-ChainStatusLine($Result, [string]$Hash) {
    @(Get-ChainLaterLine $Result | Where-Object { $_ -like "*$Hash*" })
}

function Write-ChainPaper {
    # S9.1 PAPER: genesis hash; receipts: <sha256>; content: <sha256> or absent. LF, UTF-8.
    param([string]$ColdPath, [string]$Genesis, [string]$ReceiptsHash)
    $receipts = Get-ChainReceiptName $ColdPath
    if (-not $ReceiptsHash) { $ReceiptsHash = Get-ChainTextSha256 (($receipts | ForEach-Object { "$_`n" }) -join '') }
    $contentDir = Join-Path $ColdPath 'content'
    $content = if (Test-Path -LiteralPath $contentDir) {
        $names = @(Get-ChildItem -LiteralPath $contentDir -Force | ForEach-Object Name | Sort-Object)
        'content: ' + (Get-ChainTextSha256 (($names | ForEach-Object { "$_`n" }) -join ''))
    }
    else { 'content: absent' }
    Write-ChainText (Join-Path $ColdPath 'PAPER') "$Genesis`nreceipts: $ReceiptsHash`n$content`n"
}
