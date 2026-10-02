<#
.SYNOPSIS
Install-GearConnect

.DESCRIPTION
Interactively with user credentials registers the ScubaConnect multi-tenant application within the
target tenant with the permissions for the ScubaConnect instance to run ScubaGear from its own tenant.

.Parameter AppID
This parameter provides the App ID for the application to install.
This will be provided to you along with the script

.Parameter M365Environment
This parameter is used to authenticate to the different commercial/government environments.
Valid values include "commercial", "gcc", or "gcchigh".
- For M365 tenants with E3/E5 licenses enter the value **"commercial"**.
- For M365 Government Commercial Cloud tenants with G3/G5 licenses enter the value **"gcc"**.
- For M365 Government Commercial Cloud High tenants enter the value **"gcchigh"**.
Default value is 'gcc'.

.Example
Install-GearConnect -AppID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Registers the ScubaConnect multi-tenant application for a GCC tenant.

.Example
Install-GearConnect -AppID xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -M365Environment gcchigh
Registers the ScubaConnect multi-tenant application for a GCCHigh tenant.

.NOTES
	Author : CISA
	Version : 0.2
	The user running this script needs Global Administrator, or Privileged Role Administrator plus
	Fabric Administrator, to complete all steps.
#>


param (
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string]
	$AppID,

	[Parameter(Mandatory = $false)]
	[ValidateSet("commercial", "gcc", "gcchigh", IgnoreCase = $false)]
	[ValidateNotNullOrEmpty()]
	[string]
	$M365Environment = "gcc"
)

### LOCAL DEPENDENCY CHECK ###
#Requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ModuleList')]
$ModuleList = @(
	@{
		# Install-Module
		ModuleName = 'PowerShellGet'
		ModuleVersion = [version] '2.1.0'
		MaximumVersion = [version] '2.99.99999'
	},
	@{
		# Connect-MgGraph, Disconnect-MgGraph
		ModuleName = 'Microsoft.Graph.Authentication'
		ModuleVersion = [version] '2.12.0'
		MaximumVersion = [version] '2.99.99999'
	},
	@{
		# Get-MgServicePrincipal
		ModuleName = 'Microsoft.Graph.Applications'
		ModuleVersion = [version] '2.12.0'
		MaximumVersion = [version] '2.99.99999'
	},
	@{
		# Get-MgGroup, New-MgGroup, Get-MgGroupMember, New-MgGroupMember
		ModuleName = 'Microsoft.Graph.Groups'
		ModuleVersion = [version] '2.12.0'
		MaximumVersion = [version] '2.99.99999'
	},
	@{
		# New-MgRoleManagementDirectoryRoleAssignment
		ModuleName = 'Microsoft.Graph.Identity.Governance'
		ModuleVersion = [version] '2.12.0'
		MaximumVersion = [version] '2.99.99999'
	},
	@{
		# Add-PowerAppsAccount, New-PowerAppManagementApp
		ModuleName = 'Microsoft.PowerApps.Administration.PowerShell'
		ModuleVersion = [version] '2.0.0'
		MaximumVersion = [version] '2.99.99999'
	}
)

Write-Output "Checking for required script dependencies"
$GraphVersion = $null
foreach ($Module in $ModuleList) {
	$IsGraph = $Module.ModuleName -like 'Microsoft.Graph.*'
	$Installed = Get-Module -ListAvailable -Name $Module.ModuleName |
		Where-Object { $_.Version -ge $Module.ModuleVersion -and $_.Version -le $Module.MaximumVersion }
	if ($IsGraph -and $GraphVersion) {
		$Installed = $Installed | Where-Object Version -eq $GraphVersion
	}

	if (-not $Installed) {
		Write-Output "Installing required dependency: $($Module.ModuleName)"
		$InstallParams = @{
			Name         = $Module.ModuleName
			Force        = $true
			AllowClobber = $true
			Scope        = 'CurrentUser'
		}
		if ($IsGraph -and $GraphVersion) {
			$InstallParams.RequiredVersion = $GraphVersion
		}
		else {
			$InstallParams.MaximumVersion = $Module.MaximumVersion
		}
		Install-Module @InstallParams
	}

	# All Graph submodules must match, so pin the rest to the Authentication version
	if ($Module.ModuleName -eq 'Microsoft.Graph.Authentication') {
		$GraphVersion = (Get-Module -ListAvailable -Name $Module.ModuleName |
			Where-Object { $_.Version -le $Module.MaximumVersion } |
			Sort-Object Version -Descending | Select-Object -First 1).Version
	}
}

# Import matching versions explicitly so autoloading doesn't pick a newer, mismatched module
foreach ($Module in $ModuleList | Where-Object { $_.ModuleName -like 'Microsoft.Graph.*' }) {
	Import-Module $Module.ModuleName -RequiredVersion $GraphVersion
}

### ESTABLISH GRAPH CONNECTION ###
Write-Output "Connecting..."
$EnvMap = @{commercial = "Global"; gcc = "Global"; gcchigh = "USGov"}
Connect-MgGraph -Scopes "Application.Read.All","RoleManagement.ReadWrite.Directory","Group.ReadWrite.All" `
	-Environment $EnvMap[$M365Environment] -NoWelcome
Write-Output $("#"*50)

### ADD APP TO TENANT IF NEEDED (requires user consent) ###
$AppSpId = (Get-MgServicePrincipal -Filter "appId eq '$($AppID)'").Id
if ($null -eq $AppSpId) {
	Write-Output "App doesn't exist in tenant. Consent to app in browser."
	$TldMap = @{commercial = "com"; gcc = "com"; gcchigh = "us"}
	Start-Process "https://login.microsoftonline.$($TldMap[$M365Environment])/common/adminconsent?client_id=$($AppID)"
	Write-Host -NoNewLine 'Once app shows in "Enterprise applications" in Azure, press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
	$AppSpId = (Get-MgServicePrincipal -Filter "appId eq '$($AppID)'").Id
	Write-Host
}
Write-Output "ScubaConnect App Service Principal: $AppSpId"
Write-Output $("#"*50)

### GRANT GLOBAL READER ###
Write-Output "Granting ScubaConnect App Global Reader role"
# static UUID for global reader. See https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference
$GLOBAL_READER_ROLE_ID = "f2ef992c-3afb-46b9-b7cf-a126ee74c451"
$RoleFilter = "RoleDefinitionId eq '$GLOBAL_READER_ROLE_ID' and PrincipalId eq '$AppSpId'"

if (Get-MgRoleManagementDirectoryRoleAssignment -Filter $RoleFilter) {
	Write-Output "Global Reader role is already assigned"
}
else {
	$RoleParams = @{
		"@odata.type" = "#microsoft.graph.unifiedRoleAssignment"
		PrincipalId = $AppSpId
		DirectoryScopeId = "/"
		RoleDefinitionId = $GLOBAL_READER_ROLE_ID
	}
	New-MgRoleManagementDirectoryRoleAssignment -BodyParameter $RoleParams | Out-Null
}
Write-Output "Checking Global Reader role. If added you should see one row of output below without errors"
Get-MgRoleManagementDirectoryRoleAssignment -Filter $RoleFilter
Write-Output $("#"*50)

### ADD AS POWERAPPS ADMIN ###
Write-Output "Adding ScubaConnect app as PowerApps Admin"
Import-Module Microsoft.PowerApps.Administration.PowerShell -DisableNameChecking
$EndpointMap = @{commercial = "prod"; gcc = "usgov"; gcchigh = "usgovhigh"}
Add-PowerAppsAccount -Endpoint $EndpointMap[$M365Environment]
New-PowerAppManagementApp -ApplicationId $AppID | Out-Null

Write-Output "Checking PowerApps admin. If added correctly you should see the App ID below"
Get-PowerAppManagementApp -ApplicationId $AppId
Write-Output $("#"*50)

### CONFIGURE POWERBI ACCESS (step 2 requires user interaction) ###
Write-Output "Configuring Power BI read-only admin API access"
$SecurityGroupName = "ScubaConnectSecurityGroup"

# Step 1: plain security group (not role-assignable) containing the ScubaConnect SP
$SecGroup = Get-MgGroup -Filter "displayName eq '$SecurityGroupName'" -Top 1
if ($null -eq $SecGroup) {
	$GroupParams = @{
		DisplayName     = $SecurityGroupName
		Description     = "Grants ScubaConnect read-only access to Power BI admin APIs"
		SecurityEnabled = $true
		MailEnabled     = $false
		MailNickname    = $SecurityGroupName
	}
	$SecGroup = New-MgGroup -BodyParameter $GroupParams
	Write-Output "Created security group: $($SecGroup.Id)"
}
else {
	Write-Output "Using existing security group: $($SecGroup.Id)"
}

try {
	New-MgGroupMember -GroupId $SecGroup.Id -DirectoryObjectId $AppSpId -ErrorAction Stop
	Write-Output "Added ScubaConnect SP to $SecurityGroupName"
}
catch {
	if ($_.Exception.Message -like "*already exist*") {
		Write-Output "ScubaConnect SP is already a member of $SecurityGroupName"
	}
	else {
		throw
	}
}

# Step 2: no supported API for tenant settings in gov clouds, so this is done in the portal
$PbiPortalMap = @{
	commercial = "https://app.powerbi.com"
	gcc        = "https://app.powerbigov.us"
	gcchigh    = "https://app.high.powerbigov.us"
}
Write-Output @"
In the Power BI Admin portal (requires Fabric Administrator or Global Administrator):
  1. Go to 'Tenant settings' then scroll down to 'Admin API settings'
  2. Enable 'Service principals can access read-only admin APIs'
  3. Under 'Apply to', select 'Specific security groups' and add '$SecurityGroupName'
  4. Click Apply
"@
Start-Process "$($PbiPortalMap[$M365Environment])/admin-portal/tenantSettings"
Write-Host -NoNewLine 'Once the setting is applied, press any key to continue...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Write-Host
Write-Output "Note: Power BI setting changes can take up to 15 minutes to take effect."

Write-Output $("#"*50)
Write-Output "Done! Disconnecting"
Disconnect-MgGraph | Out-Null