<#
.Synopsis

Remove-AzVMExtension.ps1 is used to remove a specified extension from all VMs in a given subscription

.Description

Remove-AzVMExtension.ps1 created to assist in removing specific extensions on all virtual machines

.Parameter Subscription

Sets the context for the Azure authentication to the specified Subscription name

.Parameter ExtensionToFind

Sets the name of the extension to remove

.Example

Remove-AzVMExtension.ps1 -Subscription "SubscriptionName" -ExtensionToFind ""IaaSAntimalware""
#>

#Requires -Module Az

Param(
    [Parameter(mandatory=$true)][String]$Subscription,
    [Parameter(mandatory=$true)][String]$ExtensionToFind
)

Connect-AzAccount -Subscription $Subscription
$CurrentSubscription = (get-azcontext).subscription.name
Write-Warning "You are changing something in Environment $($CurrentSubscription)" -warningaction Inquire
$rgs = Get-AzResourceGroup
for ($i=0; $i -lt $rgs.count; $i++)
{
    $vms = get-azvm -ResourceGroupName $rgs[$i].ResourceGroupName
    for ($a=0; $a -lt $vms.count; $a++)
    {
        $extension = Get-AzVMExtension -ResourceGroupName $rgs[$i].ResourceGroupName -VMName $vms[$a].name | Where-Object {$_.name -like $ExtensionToFind}
        if ($extension)
        {
            write-host "Attempting to remove [$($ExtensionToFind)] from VM [$($vms[$a].Name)]"
            Remove-AzVMExtension -ResourceGroupName $rgs[$i].ResourceGroupName -VMName $vms[$a].name -name $ExtensionToFind -Force
        }
        else 
        {
            write-host "Extension [$($ExtensionToFind)] not found on VM [$($vms[$a].name)]"
        }
    }

}

