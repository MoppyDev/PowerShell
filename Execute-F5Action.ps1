function F5Action
{
    Param(
        [Parameter(mandatory=$true)][ValidateSet("GetStatus","Disable","Enable")]$Action,
        [Parameter(mandatory=$true)]$Servers,
        [Parameter(mandatory=$true)]$LTMName,
        [Parameter(mandatory=$true)]$F5Username,
        [Parameter(mandatory=$true)]$F5Password
    )
    try
    {
        import-module f5-ltm

        # Create credential Object + convert password
        $F5Password = $F5Password | ConvertTo-SecureString -AsPlainText -Force
        $Credential = New-Object -typename System.Management.Automation.PSCredential ($F5Username,$F5Password)

        # Create F5 Session
        $F5Session = New-F5Session -LTMName $LTMName -LTMCredentials $Credential -PassThru -TokenLifespan 30000

        # get all nodes from the F5
        $Nodes = get-node -F5Session $F5Session

        # empty array to add nodes that match the servers passed
        $NodesToActOn = @()

        # for each server found - get all IPs and for each IP found get associated F5 node and add to the above array
        for ($a = 0; $a -lt $Servers.count; $a++)
        {
            #write-host "$($Servers[$a].Computername) contains $($Servers[$a].NetIPAddress.count) IP(s)"
            foreach($IP in $Servers[$a].NetIPAddress)
            {
                $NodesToActOn += $Nodes | Where-Object {$_.address -contains $IP}
            }
        }

        # if server count doesn't equal the nodes found count - send a warning. 
        # This could mean that a node wasn't found for each server or that more than one node was found per server
        if ($Servers.count -ne $NodesToActOn.count)
        {
            Write-warning "Count of nodes [$($NodesToActOn.count)] =/= count of servers passed: $($Servers.count)"
        }

        write-host "Performing action: $action on Computers :$($Servers.computername)"

        switch ($Action)
        {
            GetStatus {$result = $NodesToActOn | Get-NodeStats -F5Session $F5Session}
            Disable {$result = $NodesToActOn | Disable-node -F5Session $F5Session -Force}
            Enable {$result = $NodesToActOn | Enable-node -F5Session $F5Session}
        }

        return $result
     }
     catch
     {
        $ErrorMessage = $_.Exception.Message
    	write-error "Failed to perform Action [$Action] : $ErrorMessage"
     }
}