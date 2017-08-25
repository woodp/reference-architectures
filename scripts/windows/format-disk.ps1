[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$DriveLetter,

  [Parameter(Mandatory=$True)]
  [integer]$DiskNumber
)

Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
New-Partition -UseMaximumSize -DriveLetter $DriveLetter -DiskNumber $DiskNumber
Format-Volume -DriveLetter $DriveLetter -Confirm:$false -FileSystem NTFS -force 