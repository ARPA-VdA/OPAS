# Script to generate electron-builder.json with version-appropriate name and icon

# Read the version from package.json
$packageJson = Get-Content -Path "package.json" | ConvertFrom-Json
$version = $packageJson.version
Write-Host "App version: $version"

# Determine product name and icon based on version
# Version format: MAJOR.MINOR.PATCH[-prerelease]
$versionParts = $version -split '\.'
$major = [int]$versionParts[0]
$minor = [int]$versionParts[1]
$patch = $versionParts[2]
$isPreRelease = $patch -like "*-*" -or $major -eq 0

$productName = "OPAS DL Neo"
$iconPath = "./build/icons/win/icon.ico"

# Adjust based on version
if ($isPreRelease) {
    $productName = "OPAS DL Neo [PRE]"
    $iconPath = "./build/icons/alt-03-mirror/win/icon.ico"
    Write-Host "Using pre-release configuration"
} else {
    Write-Host "Using stable configuration"
}

Write-Host "Product name: $productName"
Write-Host "Icon path: $iconPath"

# Generate electron-builder.json
$config = @{
    appId = "com.manumbo.opas-dl-neo"
    productName = $productName
    files = @("dist-electron", "dist-react")
    extraResources = @("dist-electron/preload.cjs", "build/splash/splash.png")
    icon = $iconPath
    linux = @{
        target = "AppImage"
        category = "Utility"
    }
    win = @{
        target = @("portable")
        icon = $iconPath
    }
} | ConvertTo-Json -Depth 10

# Write to file
$config | Set-Content "electron-builder.json"
Write-Host "electron-builder.json generated successfully"
Write-Host "Content:"
Write-Host $config
