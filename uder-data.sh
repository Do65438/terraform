
#!/bin/bash

set -e

apt update -y
apt install nginx curl -y

# Get IMDSv2 token
TOKEN=$(curl -s -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Get Availability Zone
AZ=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Get Public IP
PUBLIC_IP=$(curl -s \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "<h1>Server deployed successfully wow Pavan!</h1>
<h2>Availability Zone: $AZ</h2>
<h2>Public IP: $PUBLIC_IP</h2>" > /var/www/html/index.html

systemctl enable nginx
systemctl start nginx

echo "Nginx installation completed"
echo "Availability Zone: $AZ"
echo "Public IP: $PUBLIC_IP"
