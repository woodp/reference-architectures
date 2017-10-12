# $DomainName         -  FQDN for the Active Directory Domain to create
# $AdminCreds         -  a PSCredentials object that contains username and password 
#                        that will be assigned to the Domain Administrator account
# $SafeModeAdminCreds -  a PSCredentials object that contains the password that will
#                        be assigned to the Safe Mode Administrator account
# $myFirstUserCreds   -  a PSCredentials object that contains the username and
#                        password for the first domain user account to create
# $RetryCount         -  defines how many retries should be performed while waiting
#                        for the domain to be provisioned
# $RetryIntervalSec   -  defines the seconds between each retry to check if the 
#                        domain has been provisioned 
Configuration CreateForest {
    param
    #v1.4
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SafeModeAdminCreds,

        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$DomainNetbiosName,

        [Parameter(Mandatory)]
        [string]$PrimaryDcIpAddress,
        
        [Parameter(Mandatory)]
        [string]$PrimaryDcName,
        
        [Parameter(Mandatory)]
        [string]$SecondaryDcName,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xStorage, xActiveDirectory, xNetworking, xPendingReboot

    $AdminSecPass = ConvertTo-SecureString $AdminCreds.Password -AsPlainText -Force
    $SafeSecPass = ConvertTo-SecureString $SafeModeAdminCreds.Password -AsPlainText -Force
    
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCreds.UserName)", $AdminSecPass)
    [System.Management.Automation.PSCredential ]$SafeDomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SafeModeAdminCreds.UserName)", $SafeSecPass)

    $Interface = Get-NetAdapter|Where-Object Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    
    @{
        AllNodes = @(

            @{
                Nodename = 'ad-vm1'
                PSDscAllowPlainTextPassword = $true
            },

            @{
                Nodename = 'ad-vm2'
                PSDscAllowPlainTextPassword = $true
            }
        )
    }

    Node $AllNodes.NodeName
    {
        LocalConfigurationManager
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        } 

        xWaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec = 60
            RetryCount = 20
        }
        
        xDisk FVolume
        {
            DiskId = 2
            DriveLetter = 'F'
            FSLabel = 'Data'
            FSFormat = 'NTFS'
            DependsOn = '[xWaitForDisk]Disk2'
        }        

        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
        }

        WindowsFeature RSAT
        {
             Ensure = "Present"
             Name = "RSAT"
        }        

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }  
    }

    Node $AllNodes.Where{$_.Name -eq $PrimaryDcName}.Nodename
    {
        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        xADDomain AddDomain
        {
            DomainName = $DomainName
            DomainNetbiosName = $DomainNetbiosName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeDomainCreds
            DatabasePath = "F:\Adds\NTDS"
            LogPath = "F:\Adds\NTDS"
            SysvolPath = "F:\Adds\SYSVOL"
            DependsOn = "[xWaitForDisk]Disk2","[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        xWaitForADDomain DomainWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomain]AddDomain"
        } 

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xWaitForADDomain]DomainWait"
        }
   }

   Node $AllNodes.Where{$_.Name -eq $SecondaryDcName}.Nodename
   {
        # Allow this machine to find the PDC and its DNS server
        [ScriptBlock]$SetScript =
        {
            Set-DnsClientServerAddress -InterfaceAlias ("$InterfaceAlias") -ServerAddresses ("$PrimaryDcIpAddress")
        }

        Script SetDnsServerAddressToFindPDC
        {
            GetScript = {return @{}}
            TestScript = {return $false} # Always run the SetScript for this.
            SetScript = $SetScript.ToString().Replace('$PrimaryDcIpAddress', $PrimaryDcIpAddress).Replace('$InterfaceAlias', $InterfaceAlias)
        }
    
        xWaitForADDomain WaitForPrimaryDC
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainAdministratorCredentials
            RetryCount = 600
            RetryIntervalSec = 30
            RebootRetryCount = 10
            DependsOn = @("[Script]SetDnsServerAddressToFindPDC")
        }

        xADDomainController SecondaryDC 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeDomainCreds
            DatabasePath = "F:\Adds\NTDS"
            LogPath = "F:\Adds\NTDS"
            SysvolPath = "F:\Adds\SYSVOL"
            DependsOn = "[xWaitForDisk]Disk2","[WindowsFeature]ADDSInstall", "[xWaitForADDomain]WaitForPrimaryDC"
        }

        # Now make sure this computer uses itself as a DNS source
        xDnsServerAddress DnsServerAddress2
        {
            Address        = @('127.0.0.1', $PrimaryDcIpAddress)
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[xADDomainController]SecondaryDC"
        }

        xPendingReboot Reboot2
        { 
            Name = "RebootServer"
            DependsOn = "[xADDomainController]SecondaryDC"
        }

   }
}