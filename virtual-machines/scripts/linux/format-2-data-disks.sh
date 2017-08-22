#
# format-2-data-disks.sh
#
#!/bin/bash

# Format and mount data1
(
echo o
echo n
echo p
echo 1
echo
echo
echo w
)|fdisk /dev/sdc
mkfs -t ext3 /dev/sdc1
mkdir /data1
mount /dev/sdc1 /data1

# Format and mount data2
(
echo o
echo n
echo p
echo 1
echo
echo
echo w
)|fdisk /dev/sdd
mkfs -t ext3 /dev/sdd1
mkdir /data2
mount /dev/sdd1 /data2