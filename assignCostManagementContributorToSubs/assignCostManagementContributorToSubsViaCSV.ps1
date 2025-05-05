# Load settings from settings.conf
$settingsPath = ".\settings.conf"
if (-not (Test-Path $settingsPath)) {
    Write-Error "Settings file not found at $settingsPath"
    exit 1
}

# Parse managedIdentityId from settings.conf
$managedIdentityId = (Get-Content $settingsPath | Where-Object { $_ -match 'managedIdentityId\s*=\s*"(.*)"' } | ForEach-Object { $matches[1] })

if ([string]::IsNullOrWhiteSpace($managedIdentityId)) {
    Write-Error "managedIdentityId not found or invalid in settings.conf"
    exit 1
}

# Load subscriptions from CSV
$subscriptionsCsvPath = ".\subscriptions.csv"
if (-not (Test-Path $subscriptionsCsvPath)) {
    Write-Error "Subscriptions CSV file not found at $subscriptionsCsvPath"
    exit 1
}

$subscriptions = Import-Csv -Path $subscriptionsCsvPath

# Verify CSV has SubscriptionId column
if (-not ($subscriptions | Get-Member -Name "SubscriptionId" -MemberType NoteProperty)) {
    Write-Error "CSV file must contain a 'SubscriptionId' column"
    exit 1
}

# Azure role definition
$roleName = "Cost Management Contributor"

# Login to Azure if not already logged in
if (-not (az account show -o none 2>$null)) {
    Write-Host "Please login to your Azure account..."
    az login
}

# Assign role to Managed Identity for each subscription
foreach ($subscription in $subscriptions) {
    $subscriptionId = $subscription.SubscriptionId.Trim()

    if ([string]::IsNullOrWhiteSpace($subscriptionId)) {
        Write-Warning "Skipping empty subscription ID."
        continue
    }

    Write-Host "Assigning '$roleName' role to Managed Identity '$managedIdentityId' for subscription '$subscriptionId'..."

    # Assign role using Azure CLI
    az role assignment create `
        --assignee-object-id $managedIdentityId `
        --assignee-principal-type ServicePrincipal `
        --role "$roleName" `
        --scope "/subscriptions/$subscriptionId"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully assigned role for subscription $subscriptionId." -ForegroundColor Green
    } else {
        Write-Warning "Failed to assign role for subscription $subscriptionId."
    }
}

Write-Host "Role assignment script completed."