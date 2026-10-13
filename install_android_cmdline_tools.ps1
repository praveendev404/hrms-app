# Install Android SDK Command Line Tools
$ANDROID_HOME = "C:\Users\sheri\AppData\Local\Android\sdk"
$CMD_TOOLS_DIR = "$ANDROID_HOME\cmdline-tools"
$LATEST_DIR = "$CMD_TOOLS_DIR\latest"

Write-Host "Installing Android SDK Command Line Tools..." -ForegroundColor Green

# Create cmdline-tools directory if it doesn't exist
if (-not (Test-Path $CMD_TOOLS_DIR)) {
    New-Item -ItemType Directory -Path $CMD_TOOLS_DIR -Force | Out-Null
    Write-Host "Created directory: $CMD_TOOLS_DIR" -ForegroundColor Yellow
}

# Download URL for latest cmdline-tools (Windows)
$CMD_TOOLS_URL = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$ZIP_FILE = "$env:TEMP\cmdline-tools.zip"

Write-Host "Downloading cmdline-tools from: $CMD_TOOLS_URL" -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

try {
    # Download the zip file
    Invoke-WebRequest -Uri $CMD_TOOLS_URL -OutFile $ZIP_FILE -UseBasicParsing
    Write-Host "Download complete!" -ForegroundColor Green
    
    # Extract to temp location first
    $TEMP_EXTRACT = "$env:TEMP\cmdline-tools-extract"
    if (Test-Path $TEMP_EXTRACT) {
        Remove-Item $TEMP_EXTRACT -Recurse -Force
    }
    Expand-Archive -Path $ZIP_FILE -DestinationPath $TEMP_EXTRACT -Force
    
    # Move to correct location (cmdline-tools/latest)
    if (Test-Path $LATEST_DIR) {
        Remove-Item $LATEST_DIR -Recurse -Force
    }
    $EXTRACTED_DIR = Get-ChildItem $TEMP_EXTRACT | Select-Object -First 1
    Move-Item -Path $EXTRACTED_DIR.FullName -Destination $LATEST_DIR -Force
    
    Write-Host "Extracted cmdline-tools to: $LATEST_DIR" -ForegroundColor Green
    
    # Clean up
    Remove-Item $ZIP_FILE -Force
    Remove-Item $TEMP_EXTRACT -Recurse -Force
    
    Write-Host "`nInstallation complete!" -ForegroundColor Green
    Write-Host "cmdline-tools installed at: $LATEST_DIR" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nPlease download manually from:" -ForegroundColor Yellow
    Write-Host "https://developer.android.com/studio#command-line-tools-only" -ForegroundColor Cyan
    Write-Host "`nExtract to: $LATEST_DIR" -ForegroundColor Yellow
    exit 1
}

