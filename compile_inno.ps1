param(
    [switch]$SkipFlutterBuild,
    [switch]$BumpPatch,
    [switch]$BumpMinor,
    [switch]$BumpBuild,
    [string]$Version = "",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$PubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
$PubspecRaw = Get-Content $PubspecPath -Raw
if ($PubspecRaw -notmatch "(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)") {
    throw "Could not parse semantic version X.Y.Z+B from pubspec.yaml"
}

$MajorMinorPatch = $Matches[1]
$BuildNumber = [int]$Matches[2]
$Parts = $MajorMinorPatch.Split('.')
$Major = [int]$Parts[0]
$Minor = [int]$Parts[1]
$Patch = [int]$Parts[2]

if ($Version -ne "") {
    if ($Version -match "^([0-9]+\.[0-9]+\.[0-9]+)(\+([0-9]+))?$") {
        $SemVersion = $Matches[1]
        if ($Matches[3]) { $BuildNumber = [int]$Matches[3] }
    } else {
        throw "Invalid -Version format '$Version'. Expected X.Y.Z or X.Y.Z+B"
    }
} elseif ($BumpMinor) {
    $Minor += 1
    $Patch = 0
    $BuildNumber += 1
    $SemVersion = "$Major.$Minor.$Patch"
} elseif ($BumpPatch) {
    $Patch += 1
    $BuildNumber += 1
    $SemVersion = "$Major.$Minor.$Patch"
} elseif ($BumpBuild) {
    $BuildNumber += 1
    $SemVersion = "$Major.$Minor.$Patch"
} else {
    $SemVersion = "$Major.$Minor.$Patch"
}

$FullVersion = "$SemVersion+$BuildNumber"
if ($FullVersion -ne "$MajorMinorPatch+$($Matches[2])") {
    $UpdatedPubspec = $PubspecRaw -replace "(?m)^version:\s*[^\r\n]+", "version: $FullVersion"
    Set-Content -Path $PubspecPath -Value $UpdatedPubspec -NoNewline
    Write-Host "Bumped pubspec.yaml version -> $FullVersion" -ForegroundColor Cyan
}

$CommitHash = (git -C $PSScriptRoot rev-parse --short HEAD 2>$null)
if (-not $CommitHash) { $CommitHash = "local" } else { $CommitHash = $CommitHash.Trim() }

# Locate Inno Setup Compiler (ISCC.exe)
$IsccCandidates = @()
$InPath = Get-Command iscc.exe -ErrorAction SilentlyContinue
if ($InPath) { $IsccCandidates += $InPath.Source }
$InnoBundleMatches = Get-ChildItem -Path "$env:USERPROFILE\.inno_bundle\versions\*\ISCC.exe" -ErrorAction SilentlyContinue
if ($InnoBundleMatches) { $IsccCandidates += ($InnoBundleMatches | Select-Object -ExpandProperty FullName) }
$IsccCandidates += @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$IsccPath = $IsccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $IsccPath) {
    throw "ISCC.exe (Inno Setup 6) not found. Install via: winget install JRSoftware.InnoSetup"
}
Write-Host "Using ISCC: $IsccPath" -ForegroundColor Gray

if ($Clean) {
    Push-Location $PSScriptRoot
    flutter clean
    flutter pub get
    Pop-Location
}

if (-not $SkipFlutterBuild) {
    Stop-Process -Name "it_pdf" -Force -ErrorAction SilentlyContinue
    Write-Host "Building Flutter Windows Release (v$FullVersion, commit: $CommitHash)..." -ForegroundColor Yellow
    Push-Location $PSScriptRoot
    flutter build windows --release `
        --build-name=$SemVersion `
        --build-number=$BuildNumber `
        --dart-define=APP_VERSION=$FullVersion `
        --dart-define=GIT_COMMIT_HASH=$CommitHash
    $ExitCode = $LASTEXITCODE
    Pop-Location
    if ($ExitCode -ne 0) {
        throw "Flutter Windows release build failed with exit code $ExitCode"
    }
}

$RunnerReleaseDir = Join-Path $PSScriptRoot "build\windows\x64\runner\Release"
$ExePath = Join-Path $RunnerReleaseDir "it_pdf.exe"
$IconPath = Join-Path $PSScriptRoot "windows\runner\resources\app_icon.ico"
$IssPath = Join-Path $PSScriptRoot "windows\packaging\installer.iss"
$OutputDir = Join-Path $PSScriptRoot "releases"

if (-not (Test-Path $ExePath)) { throw "Missing runner executable: $ExePath" }
if (-not (Test-Path $IconPath)) { throw "Missing application icon: $IconPath" }
if (-not (Test-Path $IssPath)) { throw "Missing Inno Setup script: $IssPath" }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$InstallerBaseName = "IT-PDF-x86_64-v$FullVersion-$CommitHash-Installer"
Write-Host "Compiling Inno Setup Installer -> $InstallerBaseName.exe..." -ForegroundColor Cyan

& "$IsccPath" `
    "/DMyAppVersion=$FullVersion" `
    "/DMyAppName=IT PDF" `
    "/DMyAppPublisher=Allrounder687" `
    "/DMyAppExeFolder=$RunnerReleaseDir" `
    "/DOutputDir=$OutputDir" `
    "/DOutputBaseFilename=$InstallerBaseName" `
    "/DMyAppIcon=$IconPath" `
    "$IssPath"

if ($LASTEXITCODE -ne 0) {
    throw "ISCC.exe failed with exit code $LASTEXITCODE"
}

$FinalInstaller = Join-Path $OutputDir "$InstallerBaseName.exe"
$HashInfo = Get-FileHash -Path $FinalInstaller -Algorithm SHA256
$SizeMb = [math]::Round((Get-Item $FinalInstaller).Length / 1MB, 2)

Write-Host "`nWindows Release Installer Built Successfully!" -ForegroundColor Green
Write-Host "File:   $FinalInstaller"
Write-Host "Size:   $SizeMb MB"
Write-Host "SHA256: $($HashInfo.Hash)"
