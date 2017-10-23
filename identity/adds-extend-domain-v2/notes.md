## Instructions

- Create a zip with the powershell DSC script files and the powershell modules folders (xActiveDirectory, xNetworking, xPendingReboot, xStorage).
- Upload the zip to github (or blob storage or another reachable location).
- Make sure the **Modulesurl** on the DSC extension of the JSON parameter file points to the .zip file (when using github make sure to use the raw file).
- Run azbb with onprem.json parameters file.
- Run azbb with azure.json parameters file.

## More info

### DSC scripts
- onprem-primary.ps1: set ups the AD forest, DNS, RSAT and the replication site, link and subnet (on ad-vm1 - onpremise-vnet)
- onprem-secondary.ps1: set ups DNS, RSAT and a secondary domain controller (on ad-vm2 - onpremise-vnet)
- azure.ps1: set ups set ups DNS, RSAT and a secondary domain controller (on both adds-vm1 and adds-vm2 - adds-vnet)

### azbb2 parameter files
- onprem.json: set ups the onpremise-vnet and the ad-vm1 and ad-vm2 VMs, also adds-vnet and the peering between the onpremive-vnet and adds-vnet, runs onprem-primary.ps1 and onprem-secondary.ps1 DSC scripts
- azure.json: sets up the adds-vm1 and adds-vm2 VMs (and a couple of other VMs) runs the azure.ps1 on both that VMs.

### azbb DSC extension sample

```JSON
            "extensions": [
              {
                  "name": "addsc",
                  "publisher": "Microsoft.Powershell",
                  "type": "DSC",
                  "typeHandlerVersion": "2.19",
                  "autoUpgradeMinorVersion": true,
                  "settings": {
                       "Modulesurl": "https://github.com/repo/path/adds.zip?raw=true",
                       "ConfigurationFunction":"azure.ps1\\CreateDomainController",
                       "Properties": {
                            "DomainName": "contoso.com",
                            "SiteName": "Azure-Vnet-Site",
                            "PrimaryDcIpAddress": "192.168.0.4",
                            "AdminCreds": {
                                 "UserName": "adminuser",
                                 "Password": "PrivateSettingsRef:AdminPassword"
                            },
                            "SafeModeAdminCreds": {
                                 "UserName": "safeadminuser",
                                 "Password": "PrivateSettingsRef:SafeModeAdminPassword"
                            }
                       }
                    },
                    "protectedSettings": {
                        "Items": {
                            "AdminPassword": "yourpassword",
                            "SafeModeAdminPassword": "yoursafepassword"
                        }
                    }
                }
            ]     
          }
        },
```

### Get the powershell module folders
- Install required powershell modules: xStorage, xActiveDirectory, xNetworking, xPendingReboot

```powershell
Install-Module xActiveDirectory
Install-Module xNetworking
Install-Module xPendingReboot
Install-Module xStorage
```

- Win 10 location is: C:\Program Files\WindowsPowerShell\Modules\. Otherwise use this powershell command to find path: (Get-Module -ListAvailable xActiveDirectory).path