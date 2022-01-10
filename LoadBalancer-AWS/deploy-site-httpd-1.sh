#!/bin/bash
sudo yum install httpd -y
<<<<<<< HEAD
sudo echo "<html><body><h1>Hello from server 1 in AWS</h1></body></html>" > /var/www/html/index.html
sudo systemctl start httpd
=======
sudo echo "<html><body><h1>Hello from server 1!</h1></body></html>" > /var/www/html/index.html
>>>>>>> 0fe4e5024a57a365c1344d924aa764ffc11119c9
sudo systemctl restart httpd
