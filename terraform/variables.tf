variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "app_vpc_cidr" {
  description = "CIDR block for the application VPC (web + app tiers)"
  type        = string
  default     = "10.10.0.0/16"
}

variable "data_vpc_cidr" {
  description = "CIDR block for the isolated data VPC (RDS)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "app_subnet_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "data_subnet_a_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "data_subnet_b_cidr" {
  type    = string
  default = "10.20.2.0/24"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair used for SSH / remote-exec"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local path to the private half of key_pair_name, used by the file/remote-exec provisioners"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_name" {
  type    = string
  default = "nimbuscart"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "ecr_repo_name" {
  type    = string
  default = "nimbuscart-api"
}
