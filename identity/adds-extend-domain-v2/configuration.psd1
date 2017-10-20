@{
    AllNodes = @(

        @{
            Nodename = "ad-vm1"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        },
        @{
            Nodename = "ad-vm2"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}