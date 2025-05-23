<#
    .SYNOPSIS
    Grants the specified service principal or managed identity access to an Enterprise Agreement billing account or department.

    .PARAMETER ObjectId
    The object ID of the service principal or managed identity.

    .PARAMETER TenantId
    The Azure Active Directory tenant which contains the identity.

    .PARAMETER BillingScope
    Specifies whether to grant permissions at an enrollment or department level.

    .PARAMETER BillingAccountId
    The billing account ID (enrollment number) to grant permissions against.

    .PARAMETER DepartmentId
    The department ID to grant permissions against.

    .EXAMPLE
    Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingScope Enrollment -BillingAccountId 12345
    
    Grants EA Reader permissions to the specified service principal or managed identity
    
    .EXAMPLE
    Add-FinOpsServicePrincipal -ObjectId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -BillingScope Department -BillingAccountId 12345 -DepartmentId 67890
    
    Grants department reader permissions to the specified service principal or managed identity
#>
function Add-FinOpsServicePrincipal {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,
        [Parameter(Mandatory = $true)]
        [string]$BillingAccountId,
        [Parameter(Mandatory = $false)]
        [string]$DepartmentId
    )

    $azContext = get-azcontext

    if (![string]::IsNullOrEmpty($DepartmentId) -and ![string]::IsNullOrEmpty($BillingAccountId)) {
        $BillingScope = 'Department'
    } elseif ([string]::IsNullOrEmpty($DepartmentId) -and ![string]::IsNullOrEmpty($BillingAccountId)) {
        $BillingScope = 'Enrollment'
    } else {
        throw ($LocalizedData.BillingAccountNotSpecified)
    }

    switch ($BillingScope) {
        'Enrollment' {
            if ([string]::IsNullOrEmpty($BillingAccountId)) {
                Write-Output $LocalizedData.BillingAccountNotSpecifiedForDept
                Write-Output ''
                exit 1
            }

            $roleDefinitionId = "/providers/Microsoft.Billing/billingAccounts/{0}/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e" -f $BillingAccountId
            $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/billingRoleAssignments/{2}?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, (New-Guid).Guid
            $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "{2}" } }'
            $body = $body.Replace("{0}", $ObjectId)
            $body = $body.Replace("{1}", $TenantId)
            $body = $body.Replace("{2}", $roleDefinitionId)
        }
        'Department' {
            if ([string]::IsNullOrEmpty($BillingAccountId)) {
                Write-Output $LocalizedData.BillingAccountNotSpecifiedForDept
                Write-Output ''
                exit 1
            }
            if ([string]::IsNullOrEmpty($DepartmentId)) {
                Write-Output $LocalizedData.DeptIdNotSpecified
                Write-Output ''
                exit 1
            }

            $roleDefinitionId = "/providers/Microsoft.Billing/billingAccounts/{0}/departments/{1}/billingRoleDefinitions/db609904-a47f-4794-9be8-9bd86fbffd8a" -f $BillingAccountId, $DepartmentId
            $restUri = "{0}providers/Microsoft.Billing/billingAccounts/{1}/departments/{2}/billingRoleAssignments/{3}?api-version=2019-10-01-preview" -f $azContext.Environment.ResourceManagerUrl, $BillingAccountId, $DepartmentId, (New-Guid).Guid
            $body = '{"properties": { "PrincipalId": "{0}", "PrincipalTenantId": "{1}", "roleDefinitionId": "{2}" } }'
            $body = $body.Replace("{0}", $ObjectId)
            $body = $body.Replace("{1}", $TenantId)
            $body = $body.Replace("{2}", $roleDefinitionId)
        }
        default {
            throw ($LocalizedData.InvalidBillingScope -f $BillingScope)
        }
    }

    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $token.AccessToken
    }

    try {
        Invoke-RestMethod -Uri $restUri -Method Put -Headers $authHeader -Body $body
        Write-Output ($LocalizedData.SuccessMessage1 -f $BillingScope)
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Output ($LocalizedData.AlreadyGrantedMessage1 -f $BillingScope)
        } else {
            $body
            throw $_.Exception
        }
    }
}