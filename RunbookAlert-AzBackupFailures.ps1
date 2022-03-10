$VerbosePreference = "Continue"
$WebhookURL = ""
# Ensures you do not inherit an AzureRMContext in your runbook
Disable-AzContextAutosave -Scope Process

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

$VMsFailedToBackup = @()
$RecoveryVaults = Get-AzRecoveryServicesVault
write-output "There are $($RecoveryVaults.count) Recovery Service Vaults"
for ($i=0; $i -lt $RecoveryVaults.count; $i++)
{
    $containers = Get-AzRecoveryServicesBackupContainer -BackupManagementType AzureVM -VaultId $RecoveryVaults.ID -ContainerType AzureVM
    write-output "Found $($containers.count) containers that need to be backed up"
    for ($a=0; $a -lt $containers.count; $a++)
    {
        $BackupItem = Get-AzRecoveryServicesBackupItem -Container $Containers[$a] -WorkloadType AzureVM -VaultId $RecoveryVaults[$i].ID | Where-Object {$_.LastBackupStatus -eq "Failed"}
        if ($BackupItem)
        {
            $VMsFailedToBackup += $BackupItem.VirtualMachineId.split("/")[-1].ToUpper()
        }
    }
}

if ($VMsFailedToBackup.count -eq 0)
{
    write-output "No VMs failed to backup"
}
else
{
    $AttachmentColor = "#FF0000"
    $Title = "Alert Fired :fire:"
    $SlackMsgPreJson = @{
        text= "*VMs Failed to Backup*"
        attachments= @(
            @{
                color= "$AttachmentColor"
                title= "$Title"
                author_name = "Azure Alert"
                fields= @(
                    @{
                        title = "Affected";
                        value = "$VMsFailedToBackup";
                        short = $true;
                    },
                    @{
                        title = "Recovery Vault";
                        value = "$($RecoveryVaults.name)";
                        short = $true;
                    },
                    @{
                        title = "Error";
                        value = "Check Azure logs for more details under the Recovery Vault: $($RecoveryVaults.name)";
                        short = $false;
                    }
                )
            }
        )
    }
    try 
    {
        if ($WebhookURL)
        {
            $SlackMsgJson = $SlackMsgPreJson | ConvertTo-Json -Depth 100
            $resultInvokeWebRequest = Invoke-RestMethod -Method Post -Uri $WebhookURL -Body $SlackMsgJson -ContentType 'application/json'
        }
        return $resultInvokeWebRequest
    }
    catch 
    {
        $ErrorMessage = $_.Exception.Message
        write-error "Error inside $($myinvocation.mycommand): $ErrorMessage"
        return "Error inside $($myinvocation.mycommand): $ErrorMessage"
    }
}