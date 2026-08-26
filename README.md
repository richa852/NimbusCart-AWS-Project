# NimbusCart

## AWS Three-Tier Retail Application

NimbusCart is a three-tier retail application deployed on AWS using Terraform and Docker.

### Technologies Used
- AWS
- Terraform
- Docker
- Flask
- PostgreSQL
- nginx

### Architecture
The application consists of:
- Web tier — EC2 + nginx
- App tier — EC2 + Docker + Flask API
- Data tier — PostgreSQL on Amazon RDS
- VPC peering between the App and Data VPCs

### API
- GET `/health`
- GET `/items`
- POST `/items`

### Project Report
The complete project report and supporting screenshots are included in this repository.
