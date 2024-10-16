# Next Installer for Windows
# Usage: Invoke-Expression (Invoke-WebRequest -Uri https://getnext.sh/ps -UseBasicParsing).Content
# Or: iwr -useb https://getnext.sh/ps | iex

$ErrorActionPreference = "Stop"

$GithubOrg = "mkideal"
$GithubRepo = "next"

function Write-Color([string]$Message, [string]$Color = "White", [switch]$NoNewline) {
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Get-LatestVersion {
    $url = "https://api.github.com/repos/$GithubOrg/$GithubRepo/releases/latest"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        return $response.tag_name -replace '^v', ''
    }
    catch {
        throw "Failed to get the latest version. Please check your internet connection or try again later."
    }
}

function Get-Arch {
    $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        "x86" { return "386" }
        default { throw "Unsupported architecture: $arch" }
    }
}

function Install-Next {
    $version = Get-LatestVersion
    $arch = Get-Arch
    $pkgName = "next$version.windows-$arch"
    $fileName = "$pkgName.zip"
    $url = "https://github.com/$GithubOrg/$GithubRepo/releases/download/v$version/$fileName"
    $installDir = [System.Environment]::GetFolderPath("LocalApplicationData") + "\Microsoft\WindowsApps"

    # Create a temporary directory
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Download the zip file
        Write-Color "Downloading $fileName"
        Invoke-WebRequest -Uri $url -OutFile "$tempDir\$fileName"

        # Extract the zip file
        Expand-Archive -Path "$tempDir\$fileName" -DestinationPath $tempDir

        # Ensure the installation directory exists
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir | Out-Null
        }

        # Move the files to the installation directory
        Write-Color "Installing to $installDir"
        Start-Sleep -Milliseconds 100
        Move-Item -Path "$tempDir\$pkgName\bin\*" -Destination $installDir -Force

        Write-Color "Next has been successfully installed!" "Green"
        Write-Color "Run " -NoNewline
        Write-Color "next -h" "Magenta" -NoNewline
        Write-Color " to get started or run " -NoNewline
        Write-Color "next version" "Magenta" -NoNewline
        Write-Color " to check the installed version."

        # Check if the installation directory is in the PATH
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$installDir*") {
            Write-Color "Note: The installation directory is not in your PATH." "Yellow"
            Write-Color "To use 'next' from any location, add the following directory to your PATH:" "Yellow"
            Write-Color $installDir "Cyan"
        }
    }
    catch {
        Write-Color "Error: $($_.Exception.Message)" "Red"
    }
    finally {
        # Clean up
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
    }
}

# Main execution
try {
    Install-Next
}
catch {
    Write-Color "Error: $($_.Exception.Message)" "Red"
    exit 1
}