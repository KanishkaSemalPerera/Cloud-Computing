#!/bin/bash
# EC2 user-data: runs ONCE as root on first boot.
# Works on Amazon Linux 2023. Installs nginx and serves a page showing the instance's AZ.
set -euxo pipefail

dnf update -y
dnf install -y nginx

# IMDSv2: get a session token first, then read metadata
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html>
  <body style="font-family: sans-serif">
    <h1>Hello from $INSTANCE_ID</h1>
    <p>Availability Zone: <b>$AZ</b></p>
  </body>
</html>
EOF

# Health check endpoint for the load balancer
echo "OK" > /usr/share/nginx/html/health

systemctl enable --now nginx
