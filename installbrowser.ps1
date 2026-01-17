<#
.SYNOPSIS
    Installs Vivaldi via Winget, initializes the user profile,
    and injects custom files into a selected profile.
#>

# 1. Install Vivaldi using Winget
Write-Host "--- Checking for Vivaldi Installation ---" -ForegroundColor Cyan
try {
    # We use --accept-package-agreements to avoid prompts blocking the script
    winget install --id Vivaldi.Vivaldi -e --source winget --accept-package-agreements --accept-source-agreements
}
catch {
    Write-Error "An error occurred while trying to run Winget. Please ensure App Installer is installed."
    exit
}

# 2. Define Paths and Handle First-Run Initialization
$userDataPath = "$env:LOCALAPPDATA\Vivaldi\User Data"
$vivaldiExe = "$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe"

# If Vivaldi installed to Program Files (System wide), check there instead
if (-not (Test-Path $vivaldiExe)) {
    $vivaldiExe = "${env:ProgramFiles}\Vivaldi\Application\vivaldi.exe"
}

# Check if the folder exists.
if (-not (Test-Path -Path $userDataPath)) {
    Write-Host "`n[!] Default profile not found. Initializing Vivaldi..." -ForegroundColor Yellow
    
    # Check if we can find the executable to launch it
    if (Test-Path $vivaldiExe) {
        Write-Host "Launching Vivaldi to generate profile folders..." -ForegroundColor Green
        
        # Start Vivaldi in the background
        $process = Start-Process -FilePath $vivaldiExe -PassThru
        
        # Wait 15 seconds to ensure folders are created
        Write-Host "Waiting 15 seconds for file generation..."
        Start-Sleep -Seconds 15
        
        # Close Vivaldi
        Write-Host "Closing Vivaldi..." -ForegroundColor Green
        try {
            Stop-Process -Name vivaldi -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not stop Vivaldi process automatically. It may have already closed."
        }
        
        # Short pause to release file locks
        Start-Sleep -Seconds 2
    }
    else {
        Write-Error "Could not locate 'vivaldi.exe' to perform first-run initialization."
        Write-Error "Please open Vivaldi manually once, then run this script again."
        exit
    }
}

# Double check that the folder exists now
if (-not (Test-Path -Path $userDataPath)) {
    Write-Error "The User Data folder still does not exist. Initialization failed."
    exit
}

# 3. Detect Profiles (Default and Profile X)
Write-Host "`n--- Scanning for Profiles ---" -ForegroundColor Cyan
$profiles = Get-ChildItem -Path $userDataPath -Directory | Where-Object { 
    $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$" 
}

if ($null -eq $profiles -or $profiles.Count -eq 0) {
    Write-Error "No valid profiles found in $userDataPath."
    exit
}

# 4. Profile Selection Logic
$selectedProfile = $null

if ($profiles.Count -eq 1) {
    $selectedProfile = $profiles[0]
    Write-Host "Only one profile found: '$($selectedProfile.Name)'. Selecting automatically." -ForegroundColor Green
}
else {
    Write-Host "Multiple profiles found. Please select one:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $profiles.Count; $i++) {
        Write-Host "[$($i+1)] $($profiles[$i].Name)"
    }

    do {
        $selection = Read-Host "Enter the number of the profile to use"
        if ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $profiles.Count) {
            $selectedProfile = $profiles[[int]$selection - 1]
        }
        else {
            Write-Warning "Invalid selection. Please try again."
        }
    } until ($selectedProfile -ne $null)
}

Write-Host "Target Profile: $($selectedProfile.FullName)" -ForegroundColor Green

# 5. Download the Zip Archive
$zipUrl = "https://github.com/ItzEmoji/browser/releases/latest/download/release.zip"
$tempZipPath = "$env:TEMP\vivaldi_release.zip"

Write-Host "`n--- Downloading Files ---" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZipPath -ErrorAction Stop
    Write-Host "Download complete." -ForegroundColor Green
}
catch {
    Write-Error "Failed to download the file. Error: $_"
    exit
}

# 6. Extract to the Selected Profile
Write-Host "`n--- Extracting Files ---" -ForegroundColor Cyan
try {
    # -Force overwrites existing files if they match
    Expand-Archive -Path $tempZipPath -DestinationPath $selectedProfile.FullName -Force -ErrorAction Stop
    Write-Host "Files extracted successfully to: $($selectedProfile.FullName)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to extract files. Error: $_"
    # Clean up zip even if extract fails
    Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue
    exit
}

# 7. Cleanup
Write-Host "`n--- Cleaning up ---" -ForegroundColor Cyan
if (Test-Path -Path $tempZipPath) {
    Remove-Item -Path $tempZipPath -Force
    Write-Host "Temporary zip file deleted." -ForegroundColor Green
}

Write-Host "`nDone! You can now start Vivaldi." -ForegroundColor Cyan
