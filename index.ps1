# Next Installer for Windows
# Usage: Invoke-Expression (Invoke-WebRequest -Uri https://getnext.sh -UseBasicParsing).Content
# Or: iwr -useb https://getnext.sh | iex

$ErrorActionPreference = "Stop"

$GithubOrg = "mkideal"
$GithubRepo = "next"

function Write-Color([string]$Message, [string]$Color = "White") {
    Write-Host $Message -ForegroundColor $Color
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
    $fileName = "next$version.windows-$arch.zip"
    $url = "https://github.com/$GithubOrg/$GithubRepo/releases/download/v$version/$fileName"
    $installDir = [System.Environment]::GetFolderPath("LocalApplicationData") + "\Microsoft\WindowsApps"

    Write-Color "Installing Next version $version for $arch..." "Cyan"

    # Create a temporary directory
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        # Download the zip file
        Write-Color "Downloading $fileName..." "Yellow"
        Invoke-WebRequest -Uri $url -OutFile "$tempDir\$fileName"

        # Extract the zip file
        Write-Color "Extracting files..." "Yellow"
        Expand-Archive -Path "$tempDir\$fileName" -DestinationPath $tempDir

        # Ensure the installation directory exists
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir | Out-Null
        }

        # Move the files to the installation directory
        Write-Color "Installing to $installDir..." "Yellow"
        Move-Item -Path "$tempDir\next*.windows-$arch\bin\*" -Destination $installDir -Force

        Write-Color "Next has been successfully installed!" "Green"

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