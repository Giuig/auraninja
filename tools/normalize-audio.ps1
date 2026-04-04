# Audio Normalization Script for Auraninja
# Normalizes all OGG sound files to -16 LUFS (EBU R128 standard for ambient/podcast)

param(
    [string]$TargetLUFS = "-16",
    [switch]$DryRun = $false
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$AssetsPath = Join-Path $RepoRoot "assets\sounds"

# Reload PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$FfmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue

if (-not $FfmpegCmd) {
    Write-Host "ffmpeg not found. Please install: winget install ffmpeg" -ForegroundColor Red
    exit 1
}

$FfmpegPath = $FfmpegCmd.Source
Write-Host "Using ffmpeg: $FfmpegPath" -ForegroundColor Gray
Write-Host ""

# Find all OGG files
$OggFiles = Get-ChildItem -Path $AssetsPath -Recurse -Filter "*.ogg"

if ($OggFiles.Count -eq 0) {
    Write-Host "No OGG files found in $AssetsPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($OggFiles.Count) OGG files to normalize." -ForegroundColor Cyan
Write-Host "Target: $TargetLUFS LUFS" -ForegroundColor Cyan
Write-Host ""

$Processed = 0
$Failed = @()

$FilterArg = "loudnorm=I=$TargetLUFS" + ":TP=-1.5:LRA=11"

foreach ($File in $OggFiles) {
    $Processed++
    $RelativePath = $File.FullName.Substring($RepoRoot.Length + 1)
    Write-Host "[$('{0,3}' -f $Processed)/$($OggFiles.Count)] $RelativePath" -NoNewline
    
    if ($DryRun) {
        Write-Host " [DRY RUN]" -ForegroundColor Gray
        continue
    }
    
    $TempPath = Join-Path $File.Directory "$($File.BaseName)_temp.ogg"
    
    # Run ffmpeg - use simple string args
    $FfmpegArgs = "-y -i `"$($File.FullName)`" -af `"$FilterArg`" -c:a libvorbis -q:a 6 `"$TempPath`""
    
    # Execute via cmd for reliable arg passing
    $Result = cmd /c "`"$FfmpegPath`" $FfmpegArgs" 2>&1
    $ExitCode = $LASTEXITCODE
    
    $Success = $ExitCode -eq 0 -and (Test-Path $TempPath) -and ((Get-Item $TempPath).Length -gt 1000)
    
    if ($Success) {
        Move-Item -Path $TempPath -Destination $File.FullName -Force
        Write-Host " [OK]" -ForegroundColor Green
    }
    else {
        Write-Host " [FAILED - exit: $ExitCode]" -ForegroundColor Red
        $Failed += $File.Name
        if (Test-Path $TempPath) { Remove-Item $TempPath -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Processed: $Processed files" -ForegroundColor Green

if ($Failed.Count -gt 0) {
    Write-Host "Failed: $($Failed.Count) files" -ForegroundColor Red
    $Failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}
else {
    Write-Host "All files normalized to $TargetLUFS LUFS." -ForegroundColor Green
}

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN - no files were modified." -ForegroundColor Yellow
}