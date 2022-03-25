$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"
# Ensures you do not inherit an AzureRMContext in your runbook
Disable-AzContextAutosave –Scope Process

$connection = Get-AutomationConnection -Name AzureRunAsConnection

while(!($connectionResult) -And ($logonAttempt -le 10))
{
    $LogonAttempt++
    # Logging in to Azure...
    $connectionResult =    Connect-AzAccount `
                               -ServicePrincipal `
                               -Tenant $connection.TenantID `
                               -ApplicationID $connection.ApplicationID `
                               -CertificateThumbprint $connection.CertificateThumbprint

    Start-Sleep -Seconds 10
}

try
{
    $vms = Get-AzVM
    # list resource groups in the below array to avoid hibernating VMs in that RG
    $ExceptionRGs = @()
    $RequiredTags = @{
        State = 'New' 
        Active = 'False'
        Sick = 'False' 
        Decom = 'False'
        Hibernate = 'True'}
    for ($i=0; $i -lt $vms.count; $i++)
    {
        $tags = $null
        $tags = $vms[$i].Tags
        $tagsToAdd = @()
        for ($a=0; $a -lt $RequiredTags.GetEnumerator().name.count; $a++)
        {
            $KeyName = $RequiredTags.GetEnumerator().name[$a]
            if ($KeyName -notin $tags.keys)
            {
                if (($KeyName -eq "Hibernate") -and ($vms[$i].ResourceGroupName -in $($ExceptionRGs)))
                {
                    write-output "$KeyName : False -notin $($vms[$i].name)"
                    $tagsToAdd += @{$KeyName='False'}
                }
                else 
                {
                    write-output "$KeyName : $($RequiredTags.$KeyName) -notin $($vms[$i].name)"
                    $tagsToAdd += @{$KeyName=$($RequiredTags.$KeyName)} 
                }

            }
        }

        if ($tagsToAdd)
        {
            write-output "$($vms[$i].Name) has tags to add"
            for ($x=0; $x -lt $tagsToAdd.count; $x++)
            {
                $tags += $tagsToAdd[$x]
            }
            set-azresource -ResourceGroupName $vms[$i].ResourceGroupName -name $vms[$i].Name -ResourceType "Microsoft.Compute/VirtualMachines" -Tag $tags -Force
        }
    }
}
catch 
{
    $ErrorMessage = $_.Exception.Message
    write-error "Error to set tags: $ErrorMessage"
    return "Error to set tags: $ErrorMessage"
}