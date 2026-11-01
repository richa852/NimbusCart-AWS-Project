#!/bin/bash
set -e

cd "$(dirname "$0")/terraform"

terraform init
terraform plan
terraform apply -auto-approve
