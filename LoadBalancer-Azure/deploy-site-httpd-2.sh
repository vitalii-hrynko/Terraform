#!/bin/bash
sudo apt install apache2 -y
sudo echo "<html><body><h1>Hello from server 2 in Azure</h1></body></html>" > /var/www/html/index.html
sudo systemctl restart apache2
