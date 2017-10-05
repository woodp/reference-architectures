# $DomainName         -  FQDN for the Active Directory Domain to create
# $AdminCreds         -  a PSCredentials object that contains username and password 
#                        that will be assigned to the Domain Administrator account
# $SafeModeAdminCreds -  a PSCredentials object that contains the password that will
#                        be assigned to the Safe Mode Administrator account
# $SiteName
# $RetryCount         -  defines how many retries should be performed while waiting
#                        for the domain to be provisioned
# $RetryIntervalSec   -  defines the seconds between each retry to check if the 
#                        domain has been provisioned 
Configuration CreateDomainController {
    param
    #v1.4
    (
        [Parameter(Mandatory)]
        [string]$DomainName,
      
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SafeModeAdminCreds,

        [string]$SiteName = "Default-First-Site-Name",
        
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xStorage, xActiveDirectory, xNetworking, xPendingReboot
       
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCreds.UserName)", $AdminCreds.Password)
    [System.Management.Automation.PSCredential ]$SafeDomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SafeModeAdminCreds.UserName)", $SafeModeAdminCreds.Password)

    $Interface = Get-NetAdapter|Where-Object Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        } 

        xWaitforDisk Disk2
        {
            DiskId =  2
            RetryIntervalSec = 60
            RetryCount = 60
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

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
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

        # xADDomain FirstDC 
        # {
        #     DomainName = $DomainName
        #     DomainAdministratorCredential = $DomainCreds
        #     SafemodeAdministratorPassword = $SafeDomainCreds
        #     DatabasePath = "F:\Adds\NTDS"
        #     LogPath = "F:\Adds\NTDS"
        #     SysvolPath = "F:\Adds\SYSVOL"
        #     DependsOn = "[xWaitForDisk]Disk2","[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        # }

        xADDomainController DC 
        {
            DomainName = $DomainName
            SiteName = $SiteName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeDomainCreds
            DatabasePath = "F:\Adds\NTDS"
            LogPath = "F:\Adds\NTDS"
            SysvolPath = "F:\Adds\SYSVOL"
            DependsOn = "[xWaitForDisk]Disk2","[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomainController]DC"
        } 

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

   }
}