<#
.SYNOPSIS
    Updates subscription scopes in settings.json based on entries in subscriptions.csv.

.DESCRIPTION
    Reads subscription IDs from a CSV file and updates settings.json by:
    - Removing duplicates
    - Removing subscriptions not defined in the CSV
    - Adding subscriptions from the CSV that are missing in settings.json

.PARAMETER SettingsJsonPath
    Path to the settings.json file. Default is "./settings.json"

.PARAMETER SubscriptionsCsvPath
    Path to the subscriptions.csv file. Default is "./subscriptions.csv"
#>

param(
    [string]$SettingsJsonPath = "./settings.json",
    [string]$SubscriptionsCsvPath = "./subscriptions.csv"
)

# Verify files exist
if (-not (Test-Path $SettingsJsonPath)) {
    Write-Error "Settings JSON file not found at $SettingsJsonPath"
    exit 1
}

if (-not (Test-Path $SubscriptionsCsvPath)) {
    Write-Error "Subscriptions CSV file not found at $SubscriptionsCsvPath"
    exit 1
}

try {
    # Read the current settings.json
    $settingsJson = Get-Content -Path $SettingsJsonPath -Raw | ConvertFrom-Json
    
    # Read the subscription IDs from the CSV
    $subscriptionsFromCsv = Import-Csv -Path $SubscriptionsCsvPath
    
    # Check if the CSV has a SubscriptionId column
    if (-not ($subscriptionsFromCsv | Get-Member -Name "SubscriptionId" -MemberType NoteProperty)) {
        Write-Error "CSV file does not contain a 'SubscriptionId' column"
        exit 1
    }
    
    # Extract unique subscription IDs from the CSV
    $uniqueSubscriptionIds = $subscriptionsFromCsv.SubscriptionId | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    
    Write-Host "Found $($uniqueSubscriptionIds.Count) unique subscription IDs in CSV"
    
    # Create new scopes array based on CSV subscription IDs
    $newScopes = @()
    foreach ($subscriptionId in $uniqueSubscriptionIds) {
        $newScopes += @{
            scope = "/subscriptions/$subscriptionId"
        }
    }
    
    # Update the scopes in the settings.json object
    $settingsJson.scopes = $newScopes
    
    # Convert the updated object back to JSON and preserve formatting
    $updatedJson = $settingsJson | ConvertTo-Json -Depth 10
    
    # Save the updated JSON back to the file
    $updatedJson | Out-File -FilePath $SettingsJsonPath -Encoding utf8
    
    Write-Host "Successfully updated subscription scopes in $SettingsJsonPath"
    Write-Host "Added $($newScopes.Count) unique subscription scopes"
    
    # Show the updated scopes
    Write-Host "`nUpdated scopes:"
    $newScopes | ForEach-Object {
        Write-Host "  $($_.scope)"
    }
} 
catch {
    Write-Error "An error occurred: $_"
    exit 1
}