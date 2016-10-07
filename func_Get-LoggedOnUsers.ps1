function Get-LoggedOnUsers
{
    <#
        .SYNOPSIS
            A function to query logged on users and related information.
        .Parameter DNSHostName
            A string object that accepts value from the pipeline.
            This value is used as the ComputerName parameter for Get-WmiObject.
            By default, this value is set to 'localhost'.
        .Inputs
            None or Microsoft.ActiveDirectory.Management.ADComputer
        .Outputs
            System.Array
        .Example
            PS C:\>Get-LoggedOnUsers
        .Example
            PS C:\>Get-LoggedOnUsers -ComputerName ERoot
        .Example
            PS C:\>Get-ADComputer -LDAPFilter "(dnshostname=*Waterhouse)" | Get-LoggedOnUsers
        .TODO
            Think about ignoring logons the actual function generates.
            Think about ignoring system accounts.
    #>

    param
    (
        [Parameter(Mandatory=$False, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('ComputerName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $DNSHostName = 'localhost'
    )

    begin
    {
        #Initialize array that will be used for output.
        $output = @()
    }
    process
    {
    #region- Create calculated properties for StartTime, User, and LogonId. Will be used for selecting objects from WMI queries.
        $StartTime = @{
            Name = 'StartTime'
            Expression = {([wmi]"").ConvertToDateTime($_.starttime)}
        }

        $User = @{
            Name = "User"
            Expression = {"{0}\{1}" -f $_.Antecedent.Split('"')[1],$_.Antecedent.Split('"')[3]} 
        }

        $LogonId = @{
            Name = "LogonId"
            Expression = {$_.Dependent.Split('"')[1]}
        }
    #endregion

        #Query wmi32_loggedonuser & win32_logonsession classes and select desired properties.
        $loggedOnUsers = Get-WmiObject -Class win32_loggedonuser -ComputerName $DNSHostName | Select-Object $User,$LogonId,PSComputerName
        $logonSessions = Get-WmiObject -Class win32_logonsession -ComputerName $DNSHostName | Select-Object AuthenticationPackage,LogonType,LogonId,$StartTime 

        #Initialize array that results for each individual computer will be stored.
        $objectArray = @()

        #For each logged on user, select properties from the logon session with the matching LogonId.
        foreach ($user in $loggedOnUsers)
        {
            $logonSession = $logonSessions | Where {$_.logonid -eq $user.LogonId}
            
            #Create a hashtable & object with properties for each logged on user.
            $hashtable = [ordered]@{
                User = $user.User
                StartTime = $logonSession.StartTime
                LogonType = $logonSession.LogonType
                AuthenticationPackage = $logonSession.AuthenticationPackage
                ComputerName = $user.PSComputerName
            }
            $object = New-Object psobject -Property $hashtable

            #Add each individual object to an array.
            $objectArray += $object
        }
        #Combine results for all queried computers into one array & sort by StartTime.
        $output += $objectArray | Sort-Object -Property StartTime -Descending
    }
    end
    {
        #Format the output as a table & return.
        return $output | Format-Table
    }
}