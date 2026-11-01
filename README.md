# 🛒 NimbusCart – AWS Three-Tier Retail Application

NimbusCart is a cloud-based three-tier retail application designed to demonstrate the deployment of a scalable web application on Amazon Web Services (AWS).

The project uses **Terraform for Infrastructure as Code (IaC)** and **Docker for application containerization**, with Flask powering the backend API and PostgreSQL managing application data.

## 🚀 Project Overview

The main objective of NimbusCart is to understand how a real-world web application can be structured, deployed, and managed using AWS cloud infrastructure.

The application follows a three-tier architecture:

- **Presentation Tier:** Nginx-based web layer.
- **Application Tier:** Flask REST API running inside Docker.
- **Data Tier:** PostgreSQL database hosted on Amazon RDS.

## 🏗️ System Architecture

```text
             User / Client
                   |
                   v
             Nginx Web Server
                   |
                   v
          Flask Backend API
             (Docker)
                   |
                   v
           PostgreSQL Database
             (Amazon RDS)
```

### AWS Infrastructure

- Amazon EC2 – Application and web server hosting.
- Amazon RDS – Managed PostgreSQL database.
- Amazon VPC – Network isolation.
- VPC Peering – Connectivity between application and data VPCs.
- Terraform – Infrastructure provisioning and management.

## 🛠️ Technologies Used

| Category | Technologies |
|---|---|
| Backend | Python, Flask |
| Frontend / Web | HTML, Nginx |
| Database | PostgreSQL |
| Containerization | Docker |
| Cloud | AWS |
| Infrastructure as Code | Terraform |
| Version Control | Git, GitHub |
| Operating System | Linux |

## ✨ Key Features

- Three-tier application architecture.
- RESTful API implementation.
- Containerized backend using Docker.
- Cloud infrastructure configuration using Terraform.
- PostgreSQL database integration.
- Separate application and data network environments.
- Automated infrastructure setup using shell scripts.

## 🔌 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Checks API health |
| GET | `/items` | Retrieves items |
| POST | `/items` | Creates a new item |

## 📁 Project Structure

```text
NimbusCart-AWS-Project/
│
├── app/
│   ├── api/
│   │   ├── app.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   │
│   └── frontend/
│       └── index.html
│
├── evidence/
│   └── Application screenshots
│
├── terraform/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── templates/
│
├── REPORT.md
├── script.sh
└── README.md
```

## ⚙️ Getting Started

### Prerequisites

- Git
- Docker
- Python 3
- Terraform CLI
- AWS account and configured AWS credentials

### 1. Clone the Repository

```bash
git clone https://github.com/richa852/NimbusCart-AWS-Project.git
cd NimbusCart-AWS-Project
```

### 2. Install Backend Dependencies

```bash
cd app/api
pip install -r requirements.txt
```

### 3. Configure Environment Variables

Configure the required database connection details and application settings using environment variables.

Do not commit sensitive credentials or `.env` files to GitHub.

### 4. Infrastructure Setup

Navigate to the Terraform directory:

```bash
cd ../../terraform
terraform init
terraform validate
terraform plan
```

Review the infrastructure plan before applying it.

## 📸 Project Evidence

Application testing screenshots and implementation evidence are available in the [`evidence`](./evidence) directory.

## 📄 Project Documentation

For detailed implementation information, refer to [`REPORT.md`](./REPORT.md).

## 🎯 Learning Outcomes

Through NimbusCart, I explored:

- AWS cloud infrastructure and networking.
- Three-tier application architecture.
- Infrastructure as Code using Terraform.
- Backend API development using Flask.
- Docker-based application containerization.
- PostgreSQL database integration.
- Git and GitHub version control.

## 👩‍💻 Author

**Richa Kumari**

B.Tech – Computer Science and Engineering

GitHub: [@richa852](https://github.com/richa852)

---

⭐ If you find this project interesting, feel free to explore the repository!
