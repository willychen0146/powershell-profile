### NoMercySusie's Profile setup
### Version 1.0

# Ensure this script run in Administrator mode
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        $testConnection = Test-Connection -ComputerName www.google.com -Count 1 -ErrorAction Stop
        Write-Host "Internet connection is available."
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}

# Function to install Nerd Fonts
function Install-NerdFonts {
    param (
        [string]$FontName = "JetBrainsMono",
        [string]$FontDisplayName = "JetBrainsMono NF",
        [string]$Version = "3.2.1"
    )

    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        if ($fontFamilies -notcontains "${FontDisplayName}") {
            $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${Version}/${FontName}.zip"
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFileAsync((New-Object System.Uri($fontZipUrl)), $zipFilePath)

            while ($webClient.IsBusy) {
                Start-Sleep -Seconds 2
            }

            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force
            $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
            Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                    $destination.CopyHere($_.FullName, 0x10)
                }
            }

            Remove-Item -Path $extractPath -Recurse -Force
            Remove-Item -Path $zipFilePath -Force
            Write-Host "Font ${FontDisplayName} installed successfully"
        } else {
            Write-Host "Font ${FontDisplayName} already installed"
        }
    }
    catch {
        Write-Error "Failed to download or install ${FontDisplayName} font. Error: $_"
    }
}

# Function to check if Neovim is installed
function Test-NeovimInstalled {
    try {
        $nvimPath = Get-Command nvim -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if git is installed
function Test-GitInstalled {
    try {
        $gitPath = Get-Command git -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Function to install NvChad
function Install-NvChad {
    try {
        # Backup existing Neovim config if it exists
        $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
        $nvimDataPath = "$env:LOCALAPPDATA\nvim-data"
        
        if (Test-Path $nvimConfigPath) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            Rename-Item -Path $nvimConfigPath -NewName "nvim.backup.$timestamp" -Force
            Write-Host "Existing Neovim configuration backed up."
        }
        
        if (Test-Path $nvimDataPath) {
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            Rename-Item -Path $nvimDataPath -NewName "nvim-data.backup.$timestamp" -Force
            Write-Host "Existing Neovim data backed up."
        }

        # Clone NvChad starter repository using the official command
        Write-Host "NvChad starter repository cloning, and Neovim will be launched to complete the setup, please wait..."
        git clone https://github.com/NvChad/starter $ENV:USERPROFILE\AppData\Local\nvim && nvim
        Write-Host "NvChad installed successfully."
    }
    catch {
        Write-Error "Failed to install NvChad. Error: $_"
        
        # Attempt to restore backup if installation fails
        if (Test-Path "$nvimConfigPath.backup.$timestamp") {
            Remove-Item -Path $nvimConfigPath -Force -Recurse -ErrorAction SilentlyContinue
            Rename-Item -Path "$nvimConfigPath.backup.$timestamp" -NewName "nvim" -Force
            Write-Host "Restored previous Neovim configuration from backup."
        }
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    break
}

# Profile creation or update
if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {
        # Detect Version of PowerShell & Create Profile directories if they do not exist.
        $profilePath = ""
        # PowerShell 7
        if ($PSVersionTable.PSEdition -eq "Core") {
            $profilePath = "$env:userprofile\Documents\Powershell"
        }
        # Windows PowerShell
        elseif ($PSVersionTable.PSEdition -eq "Desktop") {
            $profilePath = "$env:userprofile\Documents\WindowsPowerShell"
        }

        if (!(Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory"
        }

        # Download the profile from GitHub
        Invoke-RestMethod https://github.com/willychen0146/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created."
    }
    catch {
        Write-Error "Failed to create or update the profile. Error: $_"
    }
}
else {
    try {
        # Get the directory where the profile is located
        $profileDir = Split-Path -Path $PROFILE

        # Backup the old profile by renaming it and moving it to the same directory
        Move-Item -Path $PROFILE -Destination "$profileDir\oldprofile.ps1" -Force

        # Download the profile from GitHub
        Invoke-RestMethod https://github.com/willychen0146/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1 -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created and old profile backed up as oldprofile.ps1."
    }
    catch {
        Write-Error "Failed to backup and update the profile. Error: $_"
    }
}

# Font Install
Install-NerdFonts -FontName "JetBrainsMono" -FontDisplayName "JetBrainsMono NF"

# Oh My Posh Install
try {
    winget install -e --accept-source-agreements --accept-package-agreements JanDeDobbeleer.OhMyPosh
    Write-Host "Oh My Posh installed successfully."
}
catch {
    Write-Error "Failed to install Oh My Posh. Error: $_"
}

### Install the useful tools

# Choco install
try {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "Chocolatey installed successfully."
}
catch {
    Write-Error "Failed to install Chocolatey. Error: $_"
}

# Terminal Icons Install
try {
    Install-Module -Name Terminal-Icons -Repository PSGallery -Force
    Write-Host "Terminal Icons module installed successfully."
}
catch {
    Write-Error "Failed to install Terminal Icons module. Error: $_"
}
# zoxide Install
try {
    winget install -e --id ajeetdsouza.zoxide
    Write-Host "zoxide installed successfully."
}
catch {
    Write-Error "Failed to install zoxide. Error: $_"
}

# Install Git if not present
if (-not (Test-GitInstalled)) {
    try {
        winget install -e --accept-source-agreements --accept-package-agreements Git.Git
        # Refresh environment variables after Git installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Git installed successfully."
    }
    catch {
        Write-Error "Failed to install Git. Error: $_"
        break
    }
}

# Install Neovim if not present
if (-not (Test-NeovimInstalled)) {
    try {
        winget install -e --accept-source-agreements --accept-package-agreements Neovim.Neovim
        # Refresh environment variables after Neovim installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Neovim installed successfully."
    }
    catch {
        Write-Error "Failed to install Neovim. Error: $_"
        break
    }
}

# Install NvChad if Neovim is installed
if (Test-NeovimInstalled) {
    Install-NvChad
}

# Final check and message to the user
# if ((Test-Path -Path $PROFILE) -and ($fontFamilies -contains "JetBrainsMono NF")) {
if ((Test-Path -Path $PROFILE) -and ($fontFamilies -contains "JetBrainsMono NF") -and (Test-NeovimInstalled)) {
    Write-Host "Setup completed successfully. Please restart your PowerShell session to apply changes."
    Write-Host "NvChad has been installed. Launch Neovim to complete the setup."
} else {
    Write-Warning "Setup completed with errors. Please check the error messages above."
}