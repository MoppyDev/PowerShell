$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# this can be set as a variable in Azure
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

try
{
    $AutomationAccounts = Get-AzAutomationAccount
    $date = Get-Date

    $ExpiringCertificates = @()
    for ($i=0; $i -lt $AutomationAccounts.count; $i++)
    {
        $AzCertificate = $AutomationAccounts[$i] | Get-AzAutomationCertificate
        for ($a=0; $a -lt $AzCertificate.count; $a++)
        {
            if ($AzCertificate[$a].ExpiryTime -le $date.AddDays(30))
            {
                $ExpiringCertificates += $AzCertificate[$a]
                Write-Output "Found Certificate about to Expire. [Account: $($AzCertificate[$a].AutomationAccountName)] [Certificate Name: $($AzCertificate[$a].Name)] [ExpiryTyime: $($AzCertificate[$a].ExpiryTime.ToString())]"
            }
        }
    }
    if ($ExpiringCertificates)
    {
        $AttachmentColor = "#FF0000"
        $SlackMsgPreJson = @{
            text= "*Alert Expiring Azure Certificate* :fire:"
            attachments= @(
                @{
                    color= "$AttachmentColor"
                    fields= @(
                        @{
                            title = "*Account*";
                            value = "$($ExpiringCertificates.AutomationAccountName)";
                            short = $true;
                        },
                        @{
                            title = "*Certificate Name*";
                            value = "$($ExpiringCertificates.Name)";
                            short = $true;
                        },
                        @{
                            title = "*Expiry Time*";
                            value = "$($ExpiringCertificates.ExpiryTime.ToString())";
                            short = $true;
                        }
                    )
                }
            )
        }
        if ($WebhookURL)
        {
            $SlackMsgJson = $SlackMsgPreJson | ConvertTo-Json -Depth 100
            $resultInvokeWebRequest = Invoke-RestMethod -Method Post -Uri $WebhookURL -Body $SlackMsgJson -ContentType 'application/json'
        }
        if ($resultInvokeWebRequest -eq "ok")
        {
            return $true
        }
        else
        {
            throw "Failed to send Slack Message"
        }
    }
}
catch 
{
    $ErrorMessage = $_.Exception.Message
    write-error "Error failed to Alert on Expiring Certificates: $ErrorMessage"
    return "Error failed to Alert on Expiring Certificates: $ErrorMessage"
}
