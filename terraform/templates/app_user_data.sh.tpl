#!/bin/bash
set -e

# Install Docker + AWS CLI
apt-get update -y
apt-get install -y docker.io awscli
systemctl enable docker
systemctl start docker

# Authenticate to ECR using the instance's IAM role (no keys on disk)
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_repo}

# Pull and run the API container
docker pull ${ecr_repo}:latest

docker run -d \
  --name nimbuscart-api \
  --restart unless-stopped \
  -p 8080:8080 \
  -e DB_HOST=${db_host} \
  -e DB_NAME=${db_name} \
  -e DB_USER=${db_user} \
  -e DB_PASSWORD=${db_password} \
  ${ecr_repo}:latest
