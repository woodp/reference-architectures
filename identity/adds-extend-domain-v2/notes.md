# Powershell DSC




[Desired State Configuration Quick Start](https://docs.microsoft.com/en-us/powershell/dsc/quickstart)

## For running in azbb2

- Create a zip with the poweshell script and necessary powershell modules by adding it's corresponding folder.

- The modules are here: C:\Program Files\WindowsPowerShell\Modules\. Otherwise use this to find path: (Get-Module -ListAvailable xComputerManagement).path

- Upload the zip to a blob storage, github or another reachable location.

https://github.com/woodp/reference-architectures/blob/ad-forest-dsc/identity/adds-extend-domain-v2/CreateNewADForest.zip?raw=true



## For testing locally in the VM

### Install required modules
Install-Module xActiveDirectory

Install-Module xNetworking

Install-Module xPendingReboot

### Credentials issues

[Running DSC with user credentials](https://docs.microsoft.com/en-us/powershell/dsc/runasuser)
[Want to secure credentials in Windows PowerShell Desired State Configuration?](https://blogs.msdn.microsoft.com/powershell/2014/01/31/want-to-secure-credentials-in-windows-powershell-desired-state-configuration/)
[Securing the MOF File](https://docs.microsoft.com/en-us/powershell/dsc/securemof)
[Using Credentials with PsDscAllowPlainTextPassword and PsDscAllowDomainUser in PowerShell DSC Configuration Data](https://blogs.technet.microsoft.com/ashleymcglone/2015/12/18/using-credentials-with-psdscallowplaintextpassword-and-psdscallowdomainuser-in-powershell-dsc-configuration-data/)

ConvertTo-MOFInstance : System.InvalidOperationException error processing property 'DomainAdministratorCredential' OF
TYPE 'xADDomain': Converting and storing encrypted passwords as plain text is not recommended. For more information on
securing credentials in MOF file, please refer to MSDN blog: http://go.microsoft.com/fwlink/?LinkId=393729


### Look for the examples
For example for Storage:
https://github.com/PowerShell/xStorage/tree/dev/Modules/xStorage/Examples
SQL Server:
https://github.com/PowerShell/xSQLServer/tree/dev/Examples

Not all modules have it, or at least Active Directory does not have the examples yet.


### Run the command

```powershell

. .\CreateNewADForest.ps1

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

$c1 = Get-Credential -UserName testadminuser -Message "Password please"
$c2 = Get-Credential -UserName user2 -Message "Password please"
$c3 = Get-Credential -UserName user3 -Message "Password please"

CreateNewADForest -DomainName contoso.com -SafeModeAdminCreds $c2 -AdminCreds $c1 -myFirstUserCreds $c3 -ConfigurationData $cd
Start-DscConfiguration .\CreateNewADForest
Get-DscConfigurationStatus
$Status = Get-DscConfigurationStatus 
$Status
$Status.ResourcesNotInDesiredState

```

Be sure to specify local admin credentials in AdminCreds

### Troubleshooting:

- Under C:\Windows\System32\Configuration\ConfigurationStatus you will find *.mof files with log info.

- Under c:\packages\plugins\microsoft.powershell.dsc\2.9.1.0\
where 2.9.1.0 is the version number
inside the status folder you will find the logs
also under that, a folder with the name of the dsc script will be created,
inside that folder you will the .mof file

- Under c:\windowsazure\logs\plugins\microsoft.powershell.dsc\2.9.1.0\
where 2.9.1.0 is the version number
You will find "CommandExecution*" files, each time it runs it creates one of those
The DscHandler* files will have more detailed logging info
You can search for "error" on that files.


### Why I don't get a .mof file ??

The .mof file does not always get created, they only get spit out if a resource will be created. But even if the .mof file is not generated the script will run succesfully.



. .\adds-forest.ps1

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

$c1 = Get-Credential -UserName testadminuser -Message "Password please"
$c2 = Get-Credential -UserName testsafeadminuser -Message "Password please"

CreateForest -AdminCreds $c1 -SafeModeAdminCreds $c2 -ConfigurationData $cd
Start-DscConfiguration .\CreateForest


192.168.0.4

192.168.0.5


$cd = @{
    AllNodes = @(

        @{
            Nodename = "ad-vm1"
            Role = 'Primary'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        },

        @{
            Nodename = "ad-vm2"
            Role = 'Secondary'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

CreateForest -AdminCreds $c1 -SafeModeAdminCreds $c1 -DomainName contoso.com -DomainNetbiosName CONTOSO -PrimaryDcIpAddress 192.168.0.4 -PrimaryDcName ad-vm1 -SecondaryDcName ad-vm2 -SiteName Azure-Vnet-Site -OnpremSiteName Default-First-Site-Name -Cidr 10.0.0.0/16 -ReplicationFrequency 10 -ConfigurationData $cd

$c1 = Get-Credential -UserName testadminuser -Message "bla"

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

CreateReplicationSite -AdminCreds $c1 -DomainName contoso.com -SiteName Azure-Vnet-Site -OnpremSiteName Default-First-Site-Name -Cidr 10.0.0.0/16 -ReplicationFrequency 10 -ConfigurationData $cd

