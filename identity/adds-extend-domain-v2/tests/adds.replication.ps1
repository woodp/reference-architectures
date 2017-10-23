# $DomainName         -  FQDN for the Active Directory Domain to create
# $AdminCreds         -  a PSCredentials object that contains username and password 
#                        that will be assigned to the Domain Administrator account
# $SafeModeAdminCreds -  a PSCredentials object that contains the password that will
#                        be assigned to the Safe Mode Administrator account
# $RetryCount         -  defines how many retries should be performed while waiting
#                        for the domain to be provisioned
# $RetryIntervalSec   -  defines the seconds between each retry to check if the 
#                        domain has been provisioned 
Configuration CreateReplicationSite {
    param
    #v1.4
    (
        [Parameter(Mandatory)]
        [string]$DomainName,
      
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory=$True)]
        [string]$SiteName,
      
        [Parameter(Mandatory=$True)]
        [string]$OnpremSiteName,
      
        [Parameter(Mandatory=$True)]
        [string]$Cidr,
      
        [Parameter(Mandatory=$True)]
        [int]$ReplicationFrequency,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )
      
    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xPendingReboot
    Import-Module ADDSDeployment
      
    Node localhost
    {
        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        }

        #$AdminSecPass1 = ConvertTo-SecureString $AdminCreds.Password -AsPlainText -Force
        #[System.Management.Automation.PSCredential ]$DomainAdministratorCredentials = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($AdminCreds.UserName)", $AdminSecPass1)

        Script SetReplication
        {
            GetScript = {
                $getFilter = {Name -like "$using:SiteName"}
                $replicationSite = Get-ADReplicationSite -Filter $getFilter
                return @{ 'Result' = $replicationSite.Name }
            }
            TestScript = {
                $testFilter = {Name -like "$using:SiteName"}
                If (Get-ADReplicationSite -Filter $testFilter)
                {
                    If (Get-ADReplicationSubnet -Filter *) 
                    {
                        return $true
                    }
                }
                Write-Verbose -Message ('ReplicationSite or ReplicationSubnet not installed')
                
                return $false
            }
            SetScript = { 
                
                $Description="azure vnet ad site"
                $Location="azure subnet location"
                $SitelinkName = "AzureToOnpremLink"

                # $AdminSecPass = ConvertTo-SecureString $AdminCreds.Password -AsPlainText -Force
                # [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$(get-AdminCreds.UserName)", $AdminSecPass)
                            
                New-ADReplicationSite -Name $using:SiteName -Description $Description # -Credential $DomainCreds 
                
                New-ADReplicationSubnet -Name $using:Cidr -Site $using:SiteName -Location $Location # -Credential $DomainCreds 
                
                New-ADReplicationSiteLink -Name $SitelinkName -SitesIncluded $using:OnpremSiteName, $using:SiteName -Cost 100 -ReplicationFrequency $using:ReplicationFrequency -InterSiteTransportProtocol IP #-Credential $DomainCreds
            }
        }


        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = @("[Script]SetReplication")
        }

   }
}