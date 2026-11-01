##############################################
# Data sources
##############################################

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

##############################################
# App VPC (Web tier + App tier)
##############################################

resource "aws_vpc" "app_vpc" {
  cidr_block           = var.app_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "nimbuscart-app-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags   = { Name = "nimbuscart-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "nimbuscart-public-subnet" }
}

resource "aws_subnet" "app_private" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.app_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "nimbuscart-app-private-subnet" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "nimbuscart-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "nimbuscart-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "nimbuscart-public-rt" }
}

resource "aws_route_table" "app_private_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "nimbuscart-app-private-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "app_private_assoc" {
  subnet_id      = aws_subnet.app_private.id
  route_table_id = aws_route_table.app_private_rt.id
}

##############################################
# Data VPC (isolated - RDS only)
##############################################

resource "aws_vpc" "data_vpc" {
  cidr_block           = var.data_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "nimbuscart-data-vpc" }
}

resource "aws_subnet" "data_a" {
  vpc_id            = aws_vpc.data_vpc.id
  cidr_block        = var.data_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "nimbuscart-data-subnet-a" }
}

resource "aws_subnet" "data_b" {
  vpc_id            = aws_vpc.data_vpc.id
  cidr_block        = var.data_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "nimbuscart-data-subnet-b" }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "nimbuscart-db-subnet-group"
  subnet_ids = [aws_subnet.data_a.id, aws_subnet.data_b.id]
  tags = { Name = "nimbuscart-db-subnet-group" }
}

resource "aws_route_table" "data_rt" {
  vpc_id = aws_vpc.data_vpc.id
  tags   = { Name = "nimbuscart-data-rt" }
}

resource "aws_route_table_association" "data_a_assoc" {
  subnet_id      = aws_subnet.data_a.id
  route_table_id = aws_route_table.data_rt.id
}

resource "aws_route_table_association" "data_b_assoc" {
  subnet_id      = aws_subnet.data_b.id
  route_table_id = aws_route_table.data_rt.id
}

##############################################
# VPC Peering: app_vpc <-> data_vpc
##############################################

resource "aws_vpc_peering_connection" "app_to_data" {
  vpc_id      = aws_vpc.app_vpc.id
  peer_vpc_id = aws_vpc.data_vpc.id
  auto_accept = true
  tags = { Name = "nimbuscart-peering" }
}

# Return routes on BOTH sides - forgetting either one breaks the
# connection in that direction (see REPORT.md, Task A).
resource "aws_route" "app_private_to_data" {
  route_table_id            = aws_route_table.app_private_rt.id
  destination_cidr_block    = var.data_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_data.id
}

resource "aws_route" "public_to_data" {
  route_table_id            = aws_route_table.public_rt.id
  destination_cidr_block    = var.data_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_data.id
}

resource "aws_route" "data_to_app" {
  route_table_id            = aws_route_table.data_rt.id
  destination_cidr_block    = var.app_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_data.id
}

##############################################
# Security groups
##############################################

resource "aws_security_group" "web_sg" {
  name        = "nimbuscart-web-sg"
  description = "Web tier: HTTP/HTTPS from anywhere, SSH for admin"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten to your IP in real use
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "nimbuscart-web-sg" }
}

resource "aws_security_group" "app_sg" {
  name        = "nimbuscart-app-sg"
  description = "App tier: API port reachable only from the Web tier"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "API from Web tier only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "nimbuscart-app-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "nimbuscart-rds-sg"
  description = "RDS: Postgres reachable only from the App tier"
  vpc_id      = aws_vpc.data_vpc.id

  ingress {
    description = "Postgres from App tier CIDR (peered VPC)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.app_subnet_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "nimbuscart-rds-sg" }
}

##############################################
# RDS (PostgreSQL)
##############################################

resource "aws_db_instance" "postgres" {
  identifier             = "nimbuscart-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false
  tags = { Name = "nimbuscart-db" }
}

##############################################
# ECR repository + image build/push (local-exec)
##############################################

resource "aws_ecr_repository" "api_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = { Name = "nimbuscart-api-repo" }
}

resource "null_resource" "build_and_push_image" {
  # Rebuild/push whenever the API source changes
  triggers = {
    app_hash = filesha256("${path.module}/../app/api/app.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws ecr get-login-password --region ${var.aws_region} \
        | docker login --username AWS --password-stdin ${aws_ecr_repository.api_repo.repository_url}
      docker build -t ${var.ecr_repo_name}:latest ../app/api
      docker tag ${var.ecr_repo_name}:latest ${aws_ecr_repository.api_repo.repository_url}:latest
      docker push ${aws_ecr_repository.api_repo.repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.api_repo]
}

##############################################
# IAM role for the App tier (ECR pull only)
##############################################

resource "aws_iam_role" "app_role" {
  name = "nimbuscart-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_ecr_readonly" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "nimbuscart-app-profile"
  role = aws_iam_role.app_role.name
}

##############################################
# AMI lookup
##############################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

##############################################
# App tier EC2 (private, runs the Docker container)
##############################################

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.app_private.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.app_profile.name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/templates/app_user_data.sh.tpl", {
    aws_region  = var.aws_region
    ecr_repo    = aws_ecr_repository.api_repo.repository_url
    db_host     = aws_db_instance.postgres.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
  })

  tags = { Name = "nimbuscart-app-ec2" }

  depends_on = [
    null_resource.build_and_push_image,
    aws_db_instance.postgres,
    aws_route.app_private_to_data,
  ]
}

##############################################
# Web tier EC2 (public, nginx + frontend)
##############################################

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_pair_name

  tags = { Name = "nimbuscart-web-ec2" }

  # Copy the static frontend to the instance
  provisioner "file" {
    source      = "${path.module}/../app/frontend/"
    destination = "/tmp/frontend"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.public_ip
    }
  }

  # Install nginx, drop in the frontend + reverse-proxy config, restart
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y nginx",
      "sudo rm -rf /var/www/html/*",
      "sudo cp -r /tmp/frontend/* /var/www/html/",
      "echo '${templatefile("${path.module}/templates/nginx.conf.tpl", { app_private_ip = aws_instance.app.private_ip })}' | sudo tee /etc/nginx/sites-available/default",
      "sudo systemctl restart nginx",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.public_ip
    }
  }

  depends_on = [aws_instance.app]
}
