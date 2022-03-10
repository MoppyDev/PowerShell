<#
.Synopsis

AzUpdateVMSize.ps1 is used to change the VMs in $ResourceGroupName to a VM size of choice

.Description

AzUpdateVMSize.ps1 created to assist in updating virtual machine sizes for any virtual 
machines that are included in the resource group that is sent to this script.

.Parameter Subscription

Sets the context for the Azure authentication to the specified Subscription name

.Parameter ResourceGroupName

Specifies the resource group that contains the Virtual Machines for which sizes will be changed

.Parameter VMSize

Specifies the VM size that the virtual machines will be changed to

.Parameter Deallocate

If a VM Size is not available it requires the VM be de-allocated before changing the VM size.
Use this switch if the VMs in the resource group should first be de-allocated

.Example

AzUpdateVMSize.ps1 -Subscription "SubscriptionName" -ResourceGroupName "ResourceGroup" -VMSize "Standard_F8s_v2"
#>

#Requires -Module Az

Param(
    [Parameter(mandatory=$true)][String]$Subscription,
    [Parameter(mandatory=$true)][String]$ResourceGroupName,
    [Parameter(mandatory=$true)][String]$VMSize,
    [switch]$Deallocate
)
try
{
    Connect-AzAccount -Subscription $Subscription

    $VirtualMachines = Get-AzVm -ResourceGroupName $ResourceGroupName

    if ($Deallocate)
    {
        #stop servers here
        write-host "Deallocate option was selected. Stopping VMs first."
        $VirtualMachines | Stop-AzVm
    }

    for ($i=0; $i -lt $VirtualMachines.count; $i++)
    {
        write-output "Setting VM size on $($VirtualMachines[$i].name) from $($VirtualMachines[$i].HardwareProfile.VMSize) to $VMSize"
        $VirtualMachines[$i].hardwareprofile.vmsize = "$VMSize"
        Update-AzVM -VM $VirtualMachines[$i] -ResourceGroupName $ResourceGroupName
    }

    if ($Deallocate)
    {
        # start servers after re-size
        write-host "Deallocate option was selected. Starting VMs after update."
        $VirtualMachines | Start-AzVm
    }
}
catch
{
    $ErrorMessage = $_.Exception.Message
    write-error "Failed to update VM Size: $ErrorMessage"
}
