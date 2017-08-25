#
# single-vm.sh
#
#!/bin/bash
sh install-apache.sh
sh format-disk.sh sdc 1
sh format-disk.sh sdd 2