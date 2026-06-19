#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# Benchmark gzip, brotli, zstd, and dictionary-based brotli (DCB) / zstd (DCZ)
# decompression on pre-compressed public/index.html artifacts using hyperfine
# parameter scans. Writes a readable CSV with size ratios and timing stats.

$ScriptDir = $PSScriptRoot
$DemoDir = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '../../..')).Path

$InputFile = if ($env:INPUT_FILE) { $env:INPUT_FILE } else { Join-Path $RepoRoot 'public/index.html' }
$OutputCsv = if ($env:OUTPUT_CSV) { $env:OUTPUT_CSV } else { Join-Path $DemoDir 'assets/decompression-stats.csv' }
$DictDir = if ($env:DICT_DIR) { $env:DICT_DIR } else { Join-Path $DemoDir 'dictionaries' }
$TrainFiles = if ($env:TRAIN_FILES) { $env:TRAIN_FILES } else { Join-Path $RepoRoot 'public/index-v2.html' }
$DictMaxBytes = if ($env:DICT_MAX_BYTES) { [int]$env:DICT_MAX_BYTES } else { 32768 }
$ZstdTrainBlockBytes = if ($env:ZSTD_TRAIN_BLOCK_BYTES) { [int]$env:ZSTD_TRAIN_BLOCK_BYTES } else { 4096 }

$GzipLevelMin = if ($env:GZIP_LEVEL_MIN) { [int]$env:GZIP_LEVEL_MIN } else { 1 }
$GzipLevelMax = if ($env:GZIP_LEVEL_MAX) { [int]$env:GZIP_LEVEL_MAX } else { 9 }
$BrotliLevelMin = if ($env:BROTLI_LEVEL_MIN) { [int]$env:BROTLI_LEVEL_MIN } else { 1 }
$BrotliLevelMax = if ($env:BROTLI_LEVEL_MAX) { [int]$env:BROTLI_LEVEL_MAX } else { 11 }
$ZstdLevelMin = if ($env:ZSTD_LEVEL_MIN) { [int]$env:ZSTD_LEVEL_MIN } else { 1 }
$ZstdLevelMax = if ($env:ZSTD_LEVEL_MAX) { [int]$env:ZSTD_LEVEL_MAX } else { 19 }

$HyperfineWarmup = if ($env:HYPERFINE_WARMUP) { [int]$env:HYPERFINE_WARMUP } else { 3 }
$HyperfineMinRuns = if ($env:HYPERFINE_MIN_RUNS) { [int]$env:HYPERFINE_MIN_RUNS } else { 10 }

$DcbDict = Join-Path $DictDir 'dcb.dict'
$DczDict = Join-Path $DictDir 'dcz.dict'
$PrepareDcbScript = Join-Path $ScriptDir 'prepare-dcb-dict.js'

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "$Name not found"
        exit 1
    }
}

function Quote-Path {
    param([string]$Path)
    # hyperfine --shell=none treats backslashes as escapes on Windows
    $normalized = $Path.Replace('\', '/').Replace('"', '\"')
    return '"' + $normalized + '"'
}

function Get-HyperfineScanLevel {
    param([pscustomobject]$Row)

    if ($Row.PSObject.Properties.Name -contains 'parameter_level') {
        return [int]$Row.parameter_level
    }
    if ($Row.PSObject.Properties.Name -contains 'level') {
        return [int]$Row.level
    }

    $parameterColumn = $Row.PSObject.Properties.Name | Where-Object { $_ -like 'parameter_*' } | Select-Object -First 1
    if ($parameterColumn) {
        return [int]$Row.$parameterColumn
    }

    throw 'Hyperfine CSV row is missing a parameter level column'
}

function Get-CompressedArtifactPath {
    param(
        [string]$Algo,
        [string]$Level
    )

    return Join-Path $TmpDir "$Algo-$Level.bin"
}

function Write-CompressedArtifact {
    param(
        [string]$Algo,
        [int]$Level,
        [string]$Artifact
    )

    $inputQuoted = Quote-Path $InputFile

    switch ($Algo) {
        'gzip' {
            Invoke-CompressToFile 'gzip' "-$Level -c $inputQuoted" $Artifact
        }
        'brotli' {
            Invoke-CompressToFile 'brotli' "-f -q $Level -c $inputQuoted" $Artifact
        }
        'zstd' {
            Invoke-CompressToFile 'zstd' "-$Level -c $inputQuoted" $Artifact
        }
        'dcb' {
            Invoke-CompressToFile 'brotli' "-f -q $Level -D $(Quote-Path $DcbDict) -c $inputQuoted" $Artifact
        }
        'dcz' {
            Invoke-CompressToFile 'zstd' "-$Level -D $(Quote-Path $DczDict) -c $inputQuoted" $Artifact
        }
        default { throw "Unknown algorithm: $Algo" }
    }
}

function Invoke-CompressToFile {
    param(
        [string]$FileName,
        [string]$Arguments,
        [string]$OutputPath
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $fs = [System.IO.File]::Create($OutputPath)
    try {
        $proc.StandardOutput.BaseStream.CopyTo($fs)
    }
    finally {
        $fs.Close()
    }
    $proc.WaitForExit()

    if ($proc.ExitCode -ne 0) {
        throw "Command failed ($FileName $Arguments), exit code $($proc.ExitCode)"
    }
}

function Prepare-Dcz {
    New-Item -ItemType Directory -Force -Path $DictDir | Out-Null

    $trainArgs = @(
        '--train',
        "--maxdict=$DictMaxBytes",
        "-B$ZstdTrainBlockBytes",
        '-o', $DczDict
    ) + $TrainFileList

    Write-Host "Preparing DCZ dictionary -> $DczDict"
    & zstd @trainArgs
    Write-Host "  DCZ dictionary size: $((Get-Item $DczDict).Length) bytes"
    Write-Host
}

function Prepare-Dcb {
    if (-not (Test-Path $PrepareDcbScript)) {
        Write-Error "Missing Node prepare script: $PrepareDcbScript"
        exit 1
    }

    Write-Host "Preparing DCB dictionary -> $DcbDict"
    Write-Host '  Using Node zlib API (training-file template, zstd-dict reuse fallback)'

    $env:DCZ_DICT = $DczDict
    & node $PrepareDcbScript (@($DcbDict, $DictMaxBytes, $InputFile) + $TrainFileList)

    Write-Host "  DCB dictionary size: $((Get-Item $DcbDict).Length) bytes"
    Write-Host
}

function Prepare-CompressedArtifacts {
    param(
        [string]$Algo,
        [int]$Min,
        [int]$Max
    )

    Write-Host "Preparing compressed artifacts for $Algo (levels $Min..$Max)..."

    for ($level = $Min; $level -le $Max; $level++) {
        $artifact = Get-CompressedArtifactPath -Algo $Algo -Level $level
        Write-CompressedArtifact -Algo $Algo -Level $level -Artifact $artifact
    }
}

function Invoke-HyperfineScan {
    param(
        [string]$Algo,
        [int]$Min,
        [int]$Max,
        [string]$CmdTemplate,
        [string]$NameTemplate
    )

    $exportCsv = Join-Path $TmpDir "$Algo.csv"

    Write-Host "Benchmarking $Algo decompression (levels $Min..$Max)..."
    & hyperfine `
        --warmup $HyperfineWarmup `
        --min-runs $HyperfineMinRuns `
        --shell=none `
        --parameter-scan level $Min $Max `
        --export-csv $exportCsv `
        --command-name $NameTemplate `
        $CmdTemplate
}

function Format-BenchmarkRow {
    param(
        [string]$Algo,
        [int]$Level,
        [int64]$CompressedBytes,
        [pscustomobject]$Timing
    )

    $ratio = if ($CompressedBytes -gt 0) { $InputBytes / $CompressedBytes } else { 0 }
    $savings = if ($InputBytes -gt 0) { (1 - $CompressedBytes / $InputBytes) * 100 } else { 0 }

    return [string]::Format(
        [System.Globalization.CultureInfo]::InvariantCulture,
        '{0},{1},{2},{3},{4:F4},{5:F2},{6:F3},{7:F3},{8:F3},{9:F3},{10:F3},{11:F3},{12:F3},{13}',
        $Algo,
        $Level,
        $InputBytes,
        $CompressedBytes,
        $ratio,
        $savings,
        ([double]$Timing.mean * 1000),
        ([double]$Timing.median * 1000),
        ([double]$Timing.stddev * 1000),
        ([double]$Timing.min * 1000),
        ([double]$Timing.max * 1000),
        ([double]$Timing.user * 1000),
        ([double]$Timing.system * 1000),
        $InputBasename)
}

function Get-AppendCsvRows {
    param([string]$Algo)

    $csv = Join-Path $TmpDir "$Algo.csv"
    $rows = Import-Csv $csv

    foreach ($row in $rows) {
        $level = Get-HyperfineScanLevel -Row $row
        $artifact = Get-CompressedArtifactPath -Algo $Algo -Level $level
        $compressedBytes = (Get-Item $artifact).Length
        Format-BenchmarkRow -Algo $Algo -Level $level -CompressedBytes $compressedBytes -Timing $row
    }
}

foreach ($cmd in @('hyperfine', 'gzip', 'brotli', 'zstd', 'node')) {
    Require-Command $cmd
}

if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

$TrainFileList = $TrainFiles -split '[,\s]+' | Where-Object { $_ }
foreach ($trainFile in $TrainFileList) {
    if (-not (Test-Path $trainFile)) {
        Write-Error "Training file not found: $trainFile"
        exit 1
    }
}

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("decompress-benchmark-" + [Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
    $InputFile = (Resolve-Path $InputFile).Path
    $InputBytes = (Get-Item $InputFile).Length
    $InputBasename = Split-Path $InputFile -Leaf

    $dcbQuoted = Quote-Path $DcbDict
    $dczQuoted = Quote-Path $DczDict

    Write-Host "Input:  $InputFile ($InputBytes bytes)"
    Write-Host ("Train:  {0}" -f ($TrainFileList -join ' '))
    Write-Host "Output: $OutputCsv"
    Write-Host

    Prepare-Dcz
    Prepare-Dcb

    Prepare-CompressedArtifacts -Algo 'gzip' -Min $GzipLevelMin -Max $GzipLevelMax
    Prepare-CompressedArtifacts -Algo 'brotli' -Min $BrotliLevelMin -Max $BrotliLevelMax
    Prepare-CompressedArtifacts -Algo 'zstd' -Min $ZstdLevelMin -Max $ZstdLevelMax
    Prepare-CompressedArtifacts -Algo 'dcb' -Min $BrotliLevelMin -Max $BrotliLevelMax
    Prepare-CompressedArtifacts -Algo 'dcz' -Min $ZstdLevelMin -Max $ZstdLevelMax

    Write-Host

    $gzipArtifactTemplate = Quote-Path (Get-CompressedArtifactPath -Algo 'gzip' -Level '{level}')
    $brotliArtifactTemplate = Quote-Path (Get-CompressedArtifactPath -Algo 'brotli' -Level '{level}')
    $zstdArtifactTemplate = Quote-Path (Get-CompressedArtifactPath -Algo 'zstd' -Level '{level}')
    $dcbArtifactTemplate = Quote-Path (Get-CompressedArtifactPath -Algo 'dcb' -Level '{level}')
    $dczArtifactTemplate = Quote-Path (Get-CompressedArtifactPath -Algo 'dcz' -Level '{level}')

    Invoke-HyperfineScan -Algo 'gzip' -Min $GzipLevelMin -Max $GzipLevelMax `
        -CmdTemplate "gzip -dc $gzipArtifactTemplate" `
        -NameTemplate 'gzip -{level}'

    Invoke-HyperfineScan -Algo 'brotli' -Min $BrotliLevelMin -Max $BrotliLevelMax `
        -CmdTemplate "brotli -f -dc $brotliArtifactTemplate" `
        -NameTemplate 'brotli -q {level}'

    Invoke-HyperfineScan -Algo 'zstd' -Min $ZstdLevelMin -Max $ZstdLevelMax `
        -CmdTemplate "zstd -dc $zstdArtifactTemplate" `
        -NameTemplate 'zstd -{level}'

    Invoke-HyperfineScan -Algo 'dcb' -Min $BrotliLevelMin -Max $BrotliLevelMax `
        -CmdTemplate "brotli -f -D $dcbQuoted -dc $dcbArtifactTemplate" `
        -NameTemplate 'dcb -q {level}'

    Invoke-HyperfineScan -Algo 'dcz' -Min $ZstdLevelMin -Max $ZstdLevelMax `
        -CmdTemplate "zstd -D $dczQuoted -dc $dczArtifactTemplate" `
        -NameTemplate 'dcz -{level}'

    Write-Host
    Write-Host 'Writing results...'

    $header = 'algorithm,level,input_bytes,compressed_bytes,compression_ratio,savings_percent,mean_ms,median_ms,stddev_ms,min_ms,max_ms,user_ms,system_ms,input_file'
    $lines = @($header)
    foreach ($algo in @('gzip', 'brotli', 'zstd', 'dcb', 'dcz')) {
        $lines += Get-AppendCsvRows -Algo $algo
    }
    $lines | Set-Content -Path $OutputCsv -Encoding utf8

    Write-Host 'Done.'
    Write-Host "Results: $OutputCsv"
    Write-Host "Dictionaries: $DcbDict, $DczDict"
    Write-Host
    Import-Csv $OutputCsv | Format-Table -AutoSize
}
finally {
    if ($TmpDir -and (Test-Path $TmpDir)) {
        Remove-Item -Recurse -Force $TmpDir
    }
}
