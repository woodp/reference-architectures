#
# install-apache.sh
#
#!/bin/bash
apt-get -y update

# install Apache2
apt-get -y install apache2 

# restart Apache
apachectl restart