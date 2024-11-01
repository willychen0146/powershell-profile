### NoMercySusie's PowerShell Profile
### Version 1.0

# opt-out of telemetry before doing anything, only if PowerShell is run as admin (For security reasons, we don't want to participate in telemetry if we're running as SYSTEM)
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons

# Import Chocolatey profile if it exists
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Check for Profile Updates
function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    # Get the current profile hash from the GitHub repository
    try {
        $url = "https://raw.githubusercontent.com/willychen0146/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        }
    } catch {
        Write-Error "Unable to check for `$profile updates"
    } finally {
        Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
    }
}
Update-Profile

# Check for PowerShell Updates from the GitHub repository
function Update-PowerShell {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell

# Admin Check and Prompt Customization (Admin Suffix)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions (Check for Command Existence)
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration (Vim, Neovim, Visual Studio Code, Notepad++, Sublime Text, Notepad)
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

function Edit-Profile {
    vim $PROFILE.CurrentUserAllHosts
}

# Touch Function for File Creation
function touch($file) { "" | Out-File $file -Encoding ASCII }

# Find Files Function
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Network Utilities (Public IP Address)
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# Open WinUtil (Open Source Windows Utilities)
function winutil {
	iwr -useb https://christitus.com/win | iex
}

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = "& '$args'"
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin

# Reload the profile
function reload-profile {
    & $profile
}

# Extract a zip file
function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

# Search for a regex pattern in files
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

# Display information about volumes
function df {
    get-volume
}

# Replace text in a file
function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

# Show the path of a command
function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

# Set an environment variable
function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

# Kill processes by name
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

# List processes by name
function pgrep($name) {
    Get-Process $name
}

# Display the first n lines of a file
function head {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}

# Display the last n lines of a file
function tail {
  param($Path, $n = 10, [switch]$f = $false)
  Get-Content $Path -Tail $n -Wait:$f
}

### File and Directory Management
# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

# Quick Directory Creation
function mkdir { New-Item -ItemType Directory -Path $args }

### Navigation Shortcuts
function docs { Set-Location -Path $HOME\Documents }
function dtop { Set-Location -Path $HOME\Desktop }

# Quick Access to Editing the Profile
function ep { vim $PROFILE }

# Simplified Process Management (Kill Process by Name)
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing (la = List All, ll = List All with Hidden)
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# System Management
function diskspace {
    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, @{n='Size(GB)';e={[math]::Round($_.Size/1GB,2)}}, @{n='FreeSpace(GB)';e={[math]::Round($_.FreeSpace/1GB,2)}}
}
function ram {
    Get-WmiObject Win32_OperatingSystem | Select-Object @{n='TotalMemory(GB)';e={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}, @{n='FreeMemory(GB)';e={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
}

# npm Utilities
function npm-clean {
    Remove-Item -Recurse -Force node_modules
    Remove-Item package-lock.json
    npm cache clean --force
    npm install
}

# File Operations
function backup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$source,
        [string]$dest = "$(Get-Date -Format 'yyyy-MM-dd')_backup"
    )
    Copy-Item -Path $source -Destination $dest -Recurse
}
function compress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$path
    )
    Compress-Archive -Path $path -DestinationPath "$path.zip"
}

### Git Shortcuts
function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gp { git push }
function g { __zoxide_z github }
function gcl { git clone "$args" }
function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}
function glog { git log --oneline --graph --decorate }
function gbr { git branch }
function gch { param([string]$branch) git checkout $branch }
function gpl { git pull }

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities (Clears the DNS cache and prints a confirmation message.)
function flushdns {
	Clear-DnsClientCache
	Write-Host "DNS has been flushed"
}

### Clipboard Utilities
function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }

### Other Utilities
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function Open-Home {Set-Location -Path ~}
Set-Alias -Name home -Value Open-Home
function Open-Here {Invoke-Expression "explorer ."}
Set-Alias -Name here -Value Open-Here
function Open-RecycleBin {Invoke-Expression "explorer.exe shell:RecycleBinFolder"}
Set-Alias -Name trash -Value Open-RecycleBin
function Copy-Path-To-Clipboard {(pwd).Path | Set-Clipboard}
Set-Alias -Name cpath -Value Copy-Path-To-Clipboard
function Open-Project {Set-Location -Path "~/Documents/Project"}
Set-Alias -Name rr -Value Open-Project
function Open-Download {Set-Location -Path "~/Downloads"}
Set-Alias -Name dd -Value Open-Download
function Open-Desktop {Set-Location -Path "~/Desktop"}
Set-Alias -Name dt -Value Open-Desktop

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

$PSROptions = @{
    ContinuationPrompt = '  '
    Colors             = @{
    Parameter          = $PSStyle.Foreground.Magenta
    Selection          = $PSStyle.Background.Black
    InLinePrediction   = $PSStyle.Foreground.BrightYellow + $PSStyle.Background.BrightBlack
    }
}
Set-PSReadLineOption @PSROptions
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine

# Register Argument Completer for dotnet command
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

# Get theme from profile.ps1 or use a default theme
function Get-Theme {
    # Check if the profile file exists
    if (Test-Path -Path $PROFILE.CurrentUserAllHosts -PathType Leaf) {
        # Look for the oh-my-posh theme initialization line
        $existingTheme = Get-Content -Path $PROFILE.CurrentUserAllHosts | Select-String "oh-my-posh init pwsh --config"
        
        # If the theme configuration exists, apply it
        if ($existingTheme) {
            Invoke-Expression ($existingTheme -replace "`n|`r", "")
            return
        }
    }

    # If no theme initialization is found, apply the default theme
    Write-Host "No existing theme found. Applying default theme..."
    oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json | Invoke-Expression
}
Get-Theme

## Final Line to set prompt
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force

# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

Update-Profile - Checks for profile updates from a remote repository and updates if necessary.

Update-PowerShell - Checks for the latest PowerShell release and updates if a new version is available.

Edit-Profile - Opens the current user's profile for editing using the configured editor.

su - Opens a new elevated PowerShell window.

touch <file> - Creates a new empty file.

ff <name> - Finds files recursively with the specified name.

Get-PubIP - Retrieves the public IP address of the machine.

winutil - Runs the WinUtil script from Chris Titus Tech.

reload-profile - Reloads the current user's PowerShell profile.

unzip <file> - Extracts a zip file to the current directory.

grep <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.

df - Displays information about volumes.

sed <file> <find> <replace> - Replaces text in a file.

which <name> - Shows the path of the command.

export <name> <value> - Sets an environment variable.

pkill <name> - Kills processes by name.

pgrep <name> - Lists processes by name.

head <path> [n] - Displays the first n lines of a file (default 10).

tail <path> [n] - Displays the last n lines of a file (default 10).

nf <name> - Creates a new file with the specified name.

mkcd <dir> - Creates and changes to a new directory.

mkdir <dir> - Creates a new directory.

docs - Changes the current directory to the user's Documents folder.

dtop - Changes the current directory to the user's Desktop folder.

ep - Opens the profile for editing.

k9 <name> - Kills a process by name.

la - Lists all files in the current directory with detailed formatting.

ll - Lists all files, including hidden, in the current directory with detailed formatting.

diskspace - Show disk space usage.

ram - Show RAM usage.

npm-clean - Clean and reinstall npm packages.

backup <source> [dest] - Create backup of files/folders.

compress <path> - Compress folder/file to zip.

gs - Shortcut for 'git status'.

ga - Shortcut for 'git add .'.

gc <message> - Shortcut for 'git commit -m'.

gp - Shortcut for 'git push'.

g - Changes to the GitHub directory.

gcom <message> - Adds all changes and commits with the specified message.

lazyg <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

glog - Displays a graph of the commit history.

gbr - Lists all branches.

gch <branch> - Changes to the specified branch.

gpl - Pulls changes from the remote repository.

sysinfo - Displays detailed system information.

flushdns - Clears the DNS cache.

cpy <text> - Copies the specified text to the clipboard.

pst - Retrieves text from the clipboard.

Use 'Show-Help' to display this help message.
"@
}
Write-Host "Use 'Show-Help' to display help"

