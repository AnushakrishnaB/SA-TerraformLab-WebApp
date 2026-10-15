# Azure Infrastructure & Solution Architecture Portfolio

Hands-on Azure infrastructure projects exploring secure cloud architecture, networking, storage, disaster recovery, and Infrastructure as Code using Terraform.

These projects are part of my ongoing development in Azure infrastructure and solution architecture. Each lab documents the design objectives, architecture decisions, implementation, validation, and lessons learned.

## Projects

### 01 — Secure Azure Web Application

**Focus:** Azure networking, application security, private connectivity, and HTTPS.

- Azure Virtual Network and subnet segmentation
- Azure Application Gateway
- Azure App Service for Linux
- Private Endpoint and Private DNS
- Terraform-based deployment and connectivity testing

[View project: 01-secure-web-app](./01-secure-web-app/)

**Status:** Core infrastructure deployed; additional TLS and connectivity validation identified.

### 02 — Azure Storage Replication

**Focus:** Storage redundancy, data protection, and cloud resilience.

- Azure StorageV2 account
- Configurable storage redundancy, including RA-GRS
- Private blob container
- Terraform-based infrastructure provisioning

[View project: 02-storage-replication](./02-storage-replication/)

**Status:** Initial Terraform configuration; further validation and documentation in progress.

## Tools and Technologies

- Microsoft Azure
- Terraform / Infrastructure as Code
- Azure Virtual Network and Private DNS
- Azure Application Gateway and App Service
- Azure Storage and replication
- Azure Site Recovery — learning and lab development

## Design Principles

My focus is on understanding why architecture decisions are made, not just deploying resources. I aim to document security boundaries, connectivity, resilience, operational considerations, cost management, and validation.

## About This Portfolio

These are independent learning labs, not production customer deployments. Project status and test results are documented transparently. Resources are deployed in a personal Azure learning environment with cost management in mind.

