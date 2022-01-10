#!/bin/bash
sudo yum install httpd -y
sudo echo "The host is $(hostname -f)" > /var/www/html/index.html
sudo systemctl start httpd
