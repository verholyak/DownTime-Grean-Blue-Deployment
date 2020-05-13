#!/bin/bash
yum -y update
yum -y install httpd
myip=` curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h2>WebServer with IP: $myip</h2><br>Build by Power of Terraform !" > /var/www/html/index.html
echo "<br><font color="blue">Hello World !" >> /var/www/html/index.html
echo "<br><font color="magenta">Version 1.0 " >> /var/www/html/index.html
sudo service httpd start
chkconfig httpd on
