# Read the JSON file
$appsToInstall = Get-Content -Path "./data/InstalledWingetApps.json" | ConvertFrom-Json

# Iterate through each application
foreach ($app in $appsToInstall) {
    # Check if the app is already installed
    $installedApp = winget list | Where-Object { $_ -match $app.Id }

    if ($installedApp) {
        Write-Host "Application '$($app.Name)' is already installed."

        # Check for updates
        $updateAvailable = winget upgrade | Where-Object { $_ -match $app.Id }
        if ($updateAvailable) {
            Write-Host "Updating '$($app.Name)'..."
            winget upgrade --id $app.Id --silent
        } else {
            Write-Host "'$($app.Name)' is up-to-date."
        }
    } else {
        # Attempt to install the application
        Write-Host "Installing '$($app.Name)'..."
        try {
            winget install --id $app.Id --silent
        } catch {
            Write-Host "Source not found or failed to install '$($app.Name)'. Skipping..."
        }
    }
}

