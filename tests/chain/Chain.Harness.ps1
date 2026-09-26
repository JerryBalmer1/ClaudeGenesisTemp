#Requires -Version 7.4
# Chain harness (S12). Dot-sourced by tests/chain/C-*.ps1 inside BeforeAll; not a test itself.
#
# The module is driven the way an operator drives it: a child pwsh imports src/Genesis/Genesis.psd1 by
# explicit path, stdin is redirected (no TTY, S1.5), the working directory is an empty folder that is neither
# the Heaven nor the GnupgHome (S1.3), and stdout is captured as raw bytes (S3.6). Line two of a non-zero
# exit is the class (S7.8).
#
# Keys are made here with the B5.2 batch, never by the module (S1.4, B5.3). Export, sign and verify use the
# S4.2 argv on real gpg (B5.1). Hand-built receipts are serialized by ConvertTo-HarnessCanonical, an RFC 8785
# oracle restricted to the S3 value domain (objects, arrays, strings, integers). It is not Private/Jcs.ps1
# and does not load it.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:HarnessRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$script:HarnessModule = Join-Path $script:HarnessRoot 'src/Genesis/Genesis.psd1'
$script:HarnessBanner = [byte[]](0x70, 0x72, 0x6F, 0x76, 0x65, 0x6E, 0x61, 0x6E, 0x63, 0x65, 0x20, 0xE2, 0x89, 0xA0, 0x20, 0x74, 0x72, 0x75, 0x74, 0x68)
$script:HarnessEmpty = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$script:HarnessTimeoutMs = 300000
$script:HarnessUtf8 = [Text.UTF8Encoding]::new($false)

function Get-HarnessSha([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Get-HarnessTextSha([string]$Text) { Get-HarnessSha $script:HarnessUtf8.GetBytes($Text) }

function Set-HarnessBytes([string]$Path, [byte[]]$Bytes) {
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

function Set-HarnessText([string]$Path, [string]$Text) { Set-HarnessBytes $Path $script:HarnessUtf8.GetBytes($Text) }

# ---------------------------------------------------------------------------------------------------------
# gpg

function Get-HarnessGpg {
    $cmd = Get-Command -Name gpg -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $cmd) { throw 'harness: gpg not on PATH (B5.1)' }
    $cmd.Source
}

function Invoke-HarnessGpg([string[]]$Argv, [string]$Stdin) {
    $gpg = Get-HarnessGpg
    $PSNativeCommandUseErrorActionPreference = $false
    $out = if ($PSBoundParameters.ContainsKey('Stdin')) { $Stdin | & $gpg @Argv 2>&1 } else { & $gpg @Argv 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "harness: gpg $($Argv -join ' ') exited $LASTEXITCODE`n$($out -join "`n")" }
    $out
}

function Stop-HarnessAgent([string]$GnupgHome) {
    if (-not $GnupgHome -or -not (Test-Path -LiteralPath $GnupgHome)) { return }
    $PSNativeCommandUseErrorActionPreference = $false
    $null = & gpgconf --homedir $GnupgHome --kill all 2>&1
}

function Get-HarnessSecretKeyId([string]$GnupgHome) {
    $PSNativeCommandUseErrorActionPreference = $false
    $primary = $false
    foreach ($line in @(& (Get-HarnessGpg) --batch --no-tty --homedir $GnupgHome --list-secret-keys --with-colons 2>$null)) {
        if ($line -like 'sec:*') { $primary = $true; continue }
        if ($line -like 'ssb:*') { $primary = $false; continue }
        if ($primary -and $line -like 'fpr:*') { ($line -split ':')[9]; $primary = $false }
    }
}

function New-HarnessKey {
    # B5.2 batch into the run's GnupgHome. -Passphrase gives a protected key whose comment is not the
    # synthetic one, so the S1.5 exception cannot apply to it (C-12).
    param($Run, [string]$Name, [string]$Passphrase)
    $protected = [bool]$Passphrase
    $batch = @(
        'Key-Type: EdDSA'
        'Key-Curve: Ed25519'
        'Name-Real: GENESIS SYNTHETIC'
        if ($protected) { 'Name-Comment: GENESIS-CHAIN-PROTECTED' } else { 'Name-Comment: GENESIS-SYNTHETIC-DO-NOT-TRUST' }
        'Name-Email: synthetic@invalid'
        'Expire-Date: 1d'
        if ($protected) { "Passphrase: $Passphrase" } else { '%no-protection' }
        '%commit'
        ''
    ) -join "`n"
    $batchFile = Join-Path $Run.Scratch "$Name.batch"
    Set-HarnessText $batchFile $batch
    $before = @(Get-HarnessSecretKeyId $Run.GnupgHome)
    $null = Invoke-HarnessGpg @('--batch', '--no-tty', '--homedir', $Run.GnupgHome, '--pinentry-mode', 'loopback', '--generate-key', $batchFile)
    Remove-Item -LiteralPath $batchFile
    $new = @(Get-HarnessSecretKeyId $Run.GnupgHome | Where-Object { $_ -notin $before })
    if ($new.Count -ne 1) { throw "harness: expected one new key for $Name, found $($new.Count)" }

    $bin = Join-Path $Run.Keys "$Name.bin"
    $null = Invoke-HarnessGpg @('--batch', '--no-tty', '--homedir', $Run.GnupgHome, '--export', '--export-options', 'export-minimal', '--output', $bin, $new[0])
    $bytes = [IO.File]::ReadAllBytes($bin)
    [pscustomobject]@{
        Name        = $Name
        KeyId       = $new[0]
        Path        = $bin
        Base64      = [Convert]::ToBase64String($bytes)
        Fingerprint = Get-HarnessSha $bytes   # S4.3: SHA-256 of the export, not gpg's fingerprint
        Passphrase  = $Passphrase
    }
}

function New-HarnessSignature {
    # S4.2 sign argv. Protected keys get the passphrase on fd 0; synthetic keys get nothing.
    param($Run, $Key, [byte[]]$Payload)
    $id = [guid]::NewGuid().ToString('N')
    $payloadFile = Join-Path $Run.Scratch "$id.payload"
    $sigFile = Join-Path $Run.Scratch "$id.sig"
    Set-HarnessBytes $payloadFile $Payload
    try {
        if ($Key.Passphrase) {
            $null = Invoke-HarnessGpg -Stdin $Key.Passphrase -Argv @('--batch', '--no-tty', '--homedir', $Run.GnupgHome, '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--local-user', $Key.KeyId, '--digest-algo', 'SHA256', '--detach-sign', '--output', $sigFile, $payloadFile)
        }
        else {
            $null = Invoke-HarnessGpg @('--batch', '--no-tty', '--homedir', $Run.GnupgHome, '--pinentry-mode', 'loopback', '--local-user', $Key.KeyId, '--digest-algo', 'SHA256', '--detach-sign', '--output', $sigFile, $payloadFile)
        }
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sigFile))
    }
    finally {
        Remove-Item -LiteralPath $payloadFile, $sigFile -ErrorAction Ignore
    }
}

function Test-HarnessSignature {
    # S4.2 verify argv against a fresh temp homedir, deleted afterwards. True when gpg exits 0.
    param($Run, $Key, [byte[]]$Payload, [string]$Signature)
    $home_ = Join-Path $Run.Scratch ('verify-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $home_
    try {
        $sigFile = Join-Path $home_ 'payload.sig'
        $payloadFile = Join-Path $home_ 'payload'
        Set-HarnessBytes $sigFile ([Convert]::FromBase64String($Signature))
        Set-HarnessBytes $payloadFile $Payload
        $keyring = "$home_/keyring.kbx"
        $null = Invoke-HarnessGpg @('--batch', '--no-tty', '--homedir', $home_, '--no-default-keyring', '--keyring', $keyring, '--trust-model', 'always', '--import', $Key.Path)
        $PSNativeCommandUseErrorActionPreference = $false
        $null = & (Get-HarnessGpg) --batch --no-tty --homedir $home_ --no-default-keyring --keyring $keyring --trust-model always --verify $sigFile $payloadFile 2>&1
        $LASTEXITCODE -eq 0
    }
    finally {
        Stop-HarnessAgent $home_
        Remove-Item -LiteralPath $home_ -Recurse -ErrorAction Ignore
    }
}

# ---------------------------------------------------------------------------------------------------------
# Canonical bytes oracle (S5.1, S5.3)

function ConvertTo-HarnessString([string]$Text) {
    $sb = [Text.StringBuilder]::new('"')
    foreach ($c in $Text.ToCharArray()) {
        $n = [int]$c
        if ($n -eq 0x22) { $null = $sb.Append('\"') }
        elseif ($n -eq 0x5C) { $null = $sb.Append('\\') }
        elseif ($n -eq 0x08) { $null = $sb.Append('\b') }
        elseif ($n -eq 0x0C) { $null = $sb.Append('\f') }
        elseif ($n -eq 0x0A) { $null = $sb.Append('\n') }
        elseif ($n -eq 0x0D) { $null = $sb.Append('\r') }
        elseif ($n -eq 0x09) { $null = $sb.Append('\t') }
        elseif ($n -lt 0x20) { $null = $sb.Append('\u').Append($n.ToString('x4')) }
        else { $null = $sb.Append($c) }
    }
    $sb.Append('"').ToString()
}

function ConvertTo-HarnessCanonical($Value) {
    if ($Value -is [string]) { return ConvertTo-HarnessString $Value }
    if ($Value -is [int] -or $Value -is [long]) { return $Value.ToString([Globalization.CultureInfo]::InvariantCulture) }
    if ($Value -is [Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys)
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        return '{' + (@(foreach ($k in $keys) { (ConvertTo-HarnessString $k) + ':' + (ConvertTo-HarnessCanonical $Value[$k]) }) -join ',') + '}'
    }
    if ($Value -is [Collections.IEnumerable]) {
        return '[' + (@(foreach ($v in $Value) { ConvertTo-HarnessCanonical $v }) -join ',') + ']'
    }
    throw "harness: no canonical form for [$($Value.GetType().FullName)] (S5.3)"
}

function Get-HarnessPayload($Receipt) {
    # Canonical bytes: the receipt with signature removed (S5.1).
    $copy = [ordered]@{}
    foreach ($k in $Receipt.Keys) { if ($k -cne 'signature') { $copy[$k] = $Receipt[$k] } }
    $script:HarnessUtf8.GetBytes((ConvertTo-HarnessCanonical $copy))
}

# ---------------------------------------------------------------------------------------------------------
# Runs

function New-HarnessRun {
    # One GnupgHome with root and two successors (S14), one Heaven, one folder for context and output files.
    $dir = Join-Path $TestDrive ('run-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $run = [pscustomobject]@{
        Dir       = $dir
        GnupgHome = Join-Path $dir 'gnupg'
        Heaven    = Join-Path $dir 'heaven'
        Work      = Join-Path $dir 'work'
        Keys      = Join-Path $dir 'keys'
        Cwd       = Join-Path $dir 'cwd'
        Scratch   = Join-Path $dir 'scratch'
        Root      = $null
        Succ1     = $null
        Succ2     = $null
        Counter   = 0
    }
    foreach ($p in $run.GnupgHome, $run.Work, $run.Keys, $run.Cwd, $run.Scratch) { $null = New-Item -ItemType Directory -Path $p -Force }
    New-HarnessHeaven $run.Heaven
    $run.Root = New-HarnessKey $run 'root'
    $run.Succ1 = New-HarnessKey $run 'succ1'
    $run.Succ2 = New-HarnessKey $run 'succ2'
    $run
}

function Remove-HarnessRun($Run) {
    if ($Run) { Stop-HarnessAgent $Run.GnupgHome }
}

function New-HarnessHeaven([string]$Path) {
    # S2.1: receipts/ and content/, nothing else.
    $null = New-Item -ItemType Directory -Path (Join-Path $Path 'receipts') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Path 'content') -Force
}

function Copy-HarnessHeaven([string]$From, [string]$To, [switch]$ReceiptsOnly) {
    New-HarnessHeaven $To
    $subs = if ($ReceiptsOnly) { @('receipts') } else { @('receipts', 'content') }
    foreach ($sub in $subs) {
        Get-ChildItem -LiteralPath (Join-Path $From $sub) -Force | Copy-Item -Destination (Join-Path $To $sub) -Recurse
    }
    if ($ReceiptsOnly) { Remove-Item -LiteralPath (Join-Path $To 'content') -Recurse }
}

function New-HarnessCopy {
    # A second Heaven over the same keys, copied from the run's Heaven (or $From) into the run folder.
    param($Run, [string]$Name, [string]$From, [switch]$Empty)
    if (-not $From) { $From = $Run.Heaven }
    $to = Join-Path $Run.Dir "heaven-$Name"
    if ($Empty) { New-HarnessHeaven $to } else { Copy-HarnessHeaven $From $to }
    $to
}

function Get-HarnessNames([string]$Heaven, [string]$Sub = 'receipts') {
    $dir = Join-Path $Heaven $Sub
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    @(Get-ChildItem -LiteralPath $dir -Force | ForEach-Object Name | Sort-Object)
}

function Get-HarnessSnapshot([string]$Heaven) {
    # Path, SHA-256 and last write of every file under the Heaven (S11.1).
    @(Get-ChildItem -LiteralPath $Heaven -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
            '{0} {1} {2}' -f [IO.Path]::GetRelativePath($Heaven, $_.FullName).Replace('\', '/'),
            (Get-HarnessSha ([IO.File]::ReadAllBytes($_.FullName))), $_.LastWriteTimeUtc.Ticks
        }) -join "`n"
}

function New-HarnessFile {
    # A context or output file. -Bytes writes exactly those bytes; -Text writes UTF-8, no BOM, as given.
    param($Run, [string]$Text, [byte[]]$Bytes)
    $Run.Counter++
    $path = Join-Path $Run.Work ('f{0:d3}.txt' -f $Run.Counter)
    if ($PSBoundParameters.ContainsKey('Bytes')) { Set-HarnessBytes $path $Bytes } else { Set-HarnessText $path $Text }
    $path
}

# ---------------------------------------------------------------------------------------------------------
# Invoking the module

function Get-HarnessRunner {
    $runner = Join-Path $TestDrive 'invoke-genesis.ps1'
    if (-not (Test-Path -LiteralPath $runner)) {
        Set-HarnessText $runner ((
                '#Requires -Version 7.4',
                'param([string]$ModulePath, [string]$CommandName, [string]$ParameterFile)',
                '$ErrorActionPreference = ''Stop''',
                '$PSStyle.OutputRendering = ''PlainText''',
                'Import-Module -Name $ModulePath',
                '$parameters = Get-Content -LiteralPath $ParameterFile -Raw | ConvertFrom-Json -AsHashtable',
                '& $CommandName @parameters',
                ''
            ) -join "`n")
    }
    $runner
}

function Invoke-Genesis {
    # -HeavenPath and -GnupgHome come from the run unless -Parameters names them (S1.3). -Heaven points the
    # call at another Heaven over the same keys; -Module loads another manifest by explicit path (C-08).
    param($Run, [string]$Command, [hashtable]$Parameters = @{}, [string]$Heaven, [string]$Module = $script:HarnessModule)
    if (-not $Heaven) { $Heaven = $Run.Heaven }
    $p = [ordered]@{ HeavenPath = $Heaven; GnupgHome = $Run.GnupgHome }
    foreach ($k in $Parameters.Keys) { $p[$k] = $Parameters[$k] }

    $paramFile = Join-Path $Run.Scratch ('p-' + [guid]::NewGuid().ToString('N') + '.json')
    Set-HarnessText $paramFile (ConvertTo-Json -InputObject $p -Depth 5)
    $before = Get-HarnessNames $p.HeavenPath

    $psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($a in '-NoProfile', '-NonInteractive', '-File', (Get-HarnessRunner), $Module, $Command, $paramFile) { $psi.ArgumentList.Add($a) }
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
        if (-not $proc.WaitForExit($script:HarnessTimeoutMs)) {
            $proc.Kill($true)
            throw "harness: $Command timed out after $($script:HarnessTimeoutMs) ms"
        }
        $copy.Wait()
        $bytes = $stdout.ToArray()
        $text = $script:HarnessUtf8.GetString($bytes)
        $lines = [Collections.Generic.List[string]]::new([string[]]($text -split '\r?\n'))
        while ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
        $after = Get-HarnessNames $p.HeavenPath
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
        Remove-Item -LiteralPath $paramFile -ErrorAction Ignore
    }
}

function Format-HarnessResult($Result) {
    "$($Result.Command) exited $($Result.ExitCode)`n--- stdout`n$($Result.Text)`n--- stderr`n$($Result.Stderr)"
}

function Assert-HarnessExit {
    # 'OK' is exit 0. Anything else is a non-zero exit with that class on line two (S7.8).
    param($Result, [string]$Class)
    $because = Format-HarnessResult $Result
    if ($Class -ceq 'OK') {
        $Result.ExitCode | Should -Be 0 -Because $because
        return
    }
    $Result.ExitCode | Should -Not -Be 0 -Because $because
    $Result.Class | Should -BeExactly $Class -Because $because
}

function Invoke-HarnessWrite {
    # Setup step: must exit 0 and write exactly one receipt. Returns its hash; throws otherwise.
    param($Run, [string]$Command, [hashtable]$Parameters = @{}, [string]$Heaven)
    $r = Invoke-Genesis -Run $Run -Command $Command -Parameters $Parameters -Heaven $Heaven
    if ($r.ExitCode -ne 0 -or $r.Written.Count -ne 1) {
        throw "harness setup: $Command must exit 0 and write one receipt; wrote $($r.Written.Count)`n$(Format-HarnessResult $r)"
    }
    $r.Written[0]
}

function Test-HarnessChain {
    param($Run, [string]$Heaven, [switch]$RequireContent, [switch]$Loud, [int]$MaxReceipts)
    $p = @{}
    if ($RequireContent) { $p.RequireContent = $true }
    if ($Loud) { $p.Verbose = $true }
    if ($MaxReceipts) { $p.MaxReceipts = $MaxReceipts }
    Invoke-Genesis -Run $Run -Command 'Test-GenesisChain' -Parameters $p -Heaven $Heaven
}

# Writers, with the S14 parameter shapes.

function Add-HarnessGenesis($Run, [string]$Heaven) {
    Invoke-HarnessWrite $Run 'New-GenesisRoot' @{ RootPublicKey = $Run.Root.Path; SuccessorPublicKey = $Run.Succ1.Path; SigningKeyId = $Run.Root.KeyId } -Heaven $Heaven
}

function Get-HarnessReceiptParameters {
    param($Run, [string[]]$Context = @('context'), [string]$Output = 'output', [string]$AttributedTo)
    $p = @{
        ContextPath  = [string[]]@(foreach ($c in $Context) { New-HarnessFile $Run -Text $c })
        OutputPath   = New-HarnessFile $Run -Text $Output
        SigningKeyId = $Run.Root.KeyId
    }
    if ($AttributedTo) { $p.AttributedTo = $AttributedTo }
    $p
}

function Add-HarnessReceipt {
    param($Run, [string[]]$Context = @('context'), [string]$Output = 'output', [string]$AttributedTo, [string]$Heaven)
    Invoke-HarnessWrite $Run 'New-GenesisReceipt' (Get-HarnessReceiptParameters -Run $Run -Context $Context -Output $Output -AttributedTo $AttributedTo) -Heaven $Heaven
}

function Get-HarnessAmendmentParameters($Run) {
    @{ SuccessorPublicKey = $Run.Succ2.Path; RevokedSuccessorFingerprint = $Run.Succ1.Fingerprint; Reason = 'successor-media-lost'; SigningKeyId = $Run.Root.KeyId }
}

function Get-HarnessDiscrepancyParameters($Run, [string]$Seed = 'd') {
    @{
        CheckName    = 'HASH_MISMATCH'
        ObservedHash = Get-HarnessTextSha "$Seed-observed"
        ExpectedHash = Get-HarnessTextSha "$Seed-expected"
        SubjectId    = Get-HarnessTextSha "$Seed-subject"
        SigningKeyId = $Run.Root.KeyId
    }
}

function New-HarnessTree {
    # Genesis plus ($Count - 1) receipts. Hashes in chain order.
    param($Run, [int]$Count, [string]$Heaven)
    $hashes = [Collections.Generic.List[string]]::new()
    $hashes.Add((Add-HarnessGenesis $Run $Heaven))
    for ($i = 1; $i -lt $Count; $i++) { $hashes.Add((Add-HarnessReceipt $Run -Context "context $i" -Output "output $i" -Heaven $Heaven)) }
    , $hashes.ToArray()
}

# ---------------------------------------------------------------------------------------------------------
# Reading and mutating a tree (S13 conventions)

function Get-HarnessReceiptPath($Run, [string]$Hash, [string]$Heaven) {
    if (-not $Heaven) { $Heaven = $Run.Heaven }
    Join-Path $Heaven "receipts/$Hash.json"
}

function Read-HarnessReceipt($Run, [string]$Hash, [string]$Heaven) {
    Get-Content -LiteralPath (Get-HarnessReceiptPath $Run $Hash $Heaven) -Raw | ConvertFrom-Json -AsHashtable
}

function Write-HarnessReceipt {
    # Canonical JSON under receipts/<SHA-256 of its payload>.json. -SignWith signs the payload first.
    param($Run, $Receipt, $SignWith, [string]$Heaven)
    if (-not $Heaven) { $Heaven = $Run.Heaven }
    $payload = Get-HarnessPayload $Receipt
    if ($SignWith) { $Receipt['signature'] = New-HarnessSignature $Run $SignWith $payload }
    $hash = Get-HarnessSha $payload
    Set-HarnessText (Join-Path $Heaven "receipts/$hash.json") (ConvertTo-HarnessCanonical $Receipt)
    $hash
}

function Edit-HarnessReceipt {
    # Rewrite + rename. Without -SignWith the old signature stays.
    param($Run, [string]$Hash, [scriptblock]$Mutate, $SignWith, [string]$Heaven)
    $path = Get-HarnessReceiptPath $Run $Hash $Heaven
    $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    Remove-Item -LiteralPath $path
    & $Mutate $receipt
    Write-HarnessReceipt -Run $Run -Receipt $receipt -SignWith $SignWith -Heaven $Heaven
}

function New-HarnessBody {
    # S3.2 common fields for a hand-built receipt appended after $Parent. Non-receipt defaults (S3.2).
    param($Run, [string]$Type, [string]$Parent, [string]$Kind = 'root', $Actor, [string]$Heaven)
    if (-not $Actor) { $Actor = $Run.Root }
    $position = [long]0
    if ($Parent) { $position = [long](Read-HarnessReceipt $Run $Parent $Heaven).chain_position + 1 }
    [ordered]@{
        receipt_type   = $Type
        actor          = [ordered]@{ kind = $Kind; fingerprint = $Actor.Fingerprint }
        prompt_hash    = $script:HarnessEmpty
        prompt_context = @()
        output_hash    = $script:HarnessEmpty
        parent_hash    = $Parent
        chain_position = $position
        claimed_time   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
}

function Invoke-HarnessSignatureFlip([string]$Path) {
    # Raw, no rename: change one base64 character inside the signature value, six from its unpadded end,
    # inside the signature MPI where no verifier can ignore it.
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    $m = [regex]::Match($text, '"signature"\s*:\s*"([A-Za-z0-9+/=]+)"')
    if (-not $m.Success -or $m.Groups[1].Length -lt 16) { throw "harness: no signature value in $Path" }
    $at = $m.Groups[1].Index + $m.Groups[1].Value.TrimEnd('=').Length - 6
    $bytes[$at] = if ($bytes[$at] -eq [byte][char]'A') { [byte][char]'B' } else { [byte][char]'A' }
    [IO.File]::WriteAllBytes($Path, $bytes)
}

function Get-HarnessLine($Result, [string]$Hash) {
    # Output lines after the first that name $Hash. The Chain task bars any -Skip parameter here (S12).
    if ($Result.Lines.Count -lt 2) { return @() }
    @($Result.Lines[1..($Result.Lines.Count - 1)] | Where-Object { $_ -like "*$Hash*" })
}

function Set-HarnessPaper {
    # S9.1 PAPER: genesis hash; receipts: <sha256>; content: <sha256> or absent. LF, UTF-8.
    param([string]$Cold, [string]$Genesis, [string]$ReceiptsHash)
    if (-not $ReceiptsHash) { $ReceiptsHash = Get-HarnessTextSha (-join (Get-HarnessNames $Cold | ForEach-Object { "$_`n" })) }
    $content = if (Test-Path -LiteralPath (Join-Path $Cold 'content')) {
        'content: ' + (Get-HarnessTextSha (-join (Get-HarnessNames $Cold 'content' | ForEach-Object { "$_`n" })))
    }
    else { 'content: absent' }
    Set-HarnessText (Join-Path $Cold 'PAPER') "$Genesis`nreceipts: $ReceiptsHash`n$content`n"
}
