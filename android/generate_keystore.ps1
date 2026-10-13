# PowerShell script to generate Android release keystore
# This will create a keystore file for signing your app

Write-Host "Generating Android Release Keystore..." -ForegroundColor Green
Write-Host ""

$keystorePath = "upload-keystore.jks"
$alias = "upload"
$validity = 10000  # 10000 days (~27 years)

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "WARNING: Keystore file already exists at: $keystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to overwrite it? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Aborted. Using existing keystore." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "You will be prompted to enter:" -ForegroundColor Cyan
Write-Host "  - Keystore password (remember this!)" -ForegroundColor Cyan
Write-Host "  - Key password (can be same as keystore password)" -ForegroundColor Cyan
Write-Host "  - Your name and organization details" -ForegroundColor Cyan
Write-Host ""

# Generate keystore
$keytoolPath = "$env:JAVA_HOME\bin\keytool"
if (-not (Test-Path $keytoolPath)) {
    $keytoolPath = "keytool"  # Try system PATH
}

try {
    & $keytoolPath -genkey -v `
        -keystore $keystorePath `
        -keyalg RSA `
        -keysize 2048 `
        -validity $validity `
        -alias $alias `
        -storetype JKS

    if (Test-Path $keystorePath) {
        Write-Host ""
        Write-Host "✓ Keystore generated successfully!" -ForegroundColor Green
        Write-Host "Location: $((Get-Item $keystorePath).FullName)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "IMPORTANT:" -ForegroundColor Yellow
        Write-Host "1. Keep this keystore file safe - you'll need it for all future updates" -ForegroundColor Yellow
        Write-Host "2. Create a key.properties file with your passwords" -ForegroundColor Yellow
        Write-Host "3. Add key.properties to .gitignore" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error generating keystore: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Use Android Studio to generate the keystore:" -ForegroundColor Yellow
    Write-Host "  Build > Generate Signed Bundle / APK > Create new keystore" -ForegroundColor Cyan
}

