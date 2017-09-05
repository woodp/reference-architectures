#
# format-2-data-disks.sh
#
#!/bin/bash

# Format and mount drive 
(
echo o
echo n
echo p
echo 1
echo
echo
echo w
)|fdisk /dev/$1
mkfs -t ext3 /dev/$11
mkdir /data$2
mount /dev/$11 /data$2