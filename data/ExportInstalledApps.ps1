# Get installed applications using winget and filter only those with source 'winget'
$installedApps = winget list | Select-Object -Skip 1 | ForEach-Object {
    $app = $_ -split '\s{2,}'
    
    # Ensure the app has all required fields and the source is 'winget'
    if ($app.Count -ge 4 -and $app[3] -eq 'winget') {
        [PSCustomObject]@{
            Name    = $app[0]
            Id      = $app[1]
            Version = $app[2]
            Source  = $app[3]
        }
    }
}

# Filter out empty or irrelevant entries
$filteredApps = $installedApps | Where-Object { $_.Id -and $_.Name -and $_.Version -and $_.Source -eq 'winget' }

# Export to JSON file
$filteredApps | ConvertTo-Json | Out-File -FilePath "./data/InstalledWingetApps.json" -Encoding utf8