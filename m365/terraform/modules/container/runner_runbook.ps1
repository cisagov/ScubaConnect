Param(
    [Parameter (Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter (Mandatory = $true)]
    [string]$ContainerInstanceName,
    [Parameter (Mandatory = $true)]
    [string]$Environment
)

# Connect using a Managed Service Identity
Connect-AzAccount -Identity -Environment $Environment

Write-Output "Connected account"

Start-AzContainerGroup -Name $ContainerInstanceName -ResourceGroupName $ResourceGroupName

Write-Output "Done"