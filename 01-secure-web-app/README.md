# Azure Secure Web Application — Terraform Lab

## 1. Project Overview

This project demonstrates how to deploy and secure an Azure web application using Terraform and Azure networking services.

The goal is to build a web application that is publicly accessible through Azure Application Gateway while keeping the App Service backend accessible through a private endpoint.

The infrastructure is deployed using Terraform to practice Infrastructure as Code (IaC), Azure networking, private connectivity, HTTPS, DNS resolution, application health monitoring, and traffic routing.

**Project type:** Azure Architecture / Infrastructure as Code  
**Cloud provider:** Microsoft Azure  
**IaC tool:** Terraform  
**Language:** HCL  
**Application platform:** Azure App Service (Linux)

## 2. Architecture

### High-level architecture

```text
                         Internet
                            |
                            | HTTPS / 443
                            v
                 Azure Public IP Address
                            |
                            v
                 Azure Application Gateway
                    HTTPS Listener
                    TLS Certificate
                    Request Routing Rule
                    Health Probe
                            |
                            | HTTPS / 443
                            v
                     Azure VNet
                            |
                  Private Endpoint Subnet
                            |
                            v
                  App Service Private Endpoint
                            |
                            v
                     Azure App Service
                      Linux Web App


       Linux Test VM --------> Private Endpoint
              |
              +--------------> Internet (outbound test)

       Private DNS Zone:
       privatelink.azurewebsites.net
```

The Linux test VM is used to validate private DNS resolution and connectivity to the App Service.

### Traffic flow

1. A user connects to the Application Gateway through its public IP address.
2. The HTTPS listener accepts the incoming connection and uses the configured TLS certificate.
3. The routing rule forwards the request to the App Service backend pool.
4. The gateway resolves the App Service hostname using the configured DNS arrangement.
5. The backend hostname resolves to the private endpoint IP address.
6. The gateway connects to the App Service over HTTPS.
7. The gateway health probe monitors the backend's availability.

The private endpoint provides private inbound connectivity to the App Service. App Service VNet integration is a separate feature that allows the web application to access supported resources in the virtual network for outbound connections.

## 3. Azure Resources

| Resource | Name | Purpose |
|---|---|---|
| Resource Group | `rg-azlab-web-prod` | Contains the lab resources |
| Virtual Network | `vnet-azlab-prod` | Provides private network connectivity |
| App Service subnet | `snet-app-prod` | Application-related network resources |
| Application Gateway subnet | `snet-gateway-prod` | Dedicated subnet for Application Gateway |
| Private Endpoint subnet | `snet-endpoint-prod` | Hosts the App Service private endpoint |
| App Service Plan | `asp-azlab-web` | Provides compute resources for the web application |
| Linux Web App | `app-azlab-web` | Hosts the web application |
| Private Endpoint | `pe-app-azlab-web` | Provides private access to the App Service |
| Application Gateway | `agw-azlab-web-prod` | Provides the public HTTPS entry point and routes traffic |
| Public IP | `pip-agw-azlab-web-prod` | Provides public access to Application Gateway |
| Private DNS Zone | `privatelink.azurewebsites.net` | Supports private name resolution for App Service |
| Linux Test VM | `vm-azlab-test` | Used to test private connectivity and outbound access |

### Important network addresses observed during testing

- Private endpoint IP: `10.10.3.4`
- Linux test VM IP: `10.10.4.4`
- Application Gateway public IP observed during testing: `4.205.12.93`
- App Service hostname: `app-azlab-web.azurewebsites.net`

These are lab observations, not guaranteed permanent addresses. Recheck them after recreating the infrastructure.

## 4. Terraform Project Structure

Project directory:

`Terraform-Azure -Lab/01-secure-web-app`

Expected Terraform files:

```text
01-secure-web-app/
├── main.tf
├── network.tf
├── variables.tf
├── provider.tf
├── outputs.tf
├── terraform.tfvars       # Local configuration; do not commit secrets
├── .gitignore
└── README.md
```

File responsibilities:

- **`provider.tf`** — Configures Terraform and the AzureRM provider.
- **`variables.tf`** — Declares configurable values such as resource names, locations, SKU settings, and certificate paths.
- **`main.tf`** — Defines the main application and related infrastructure resources.
- **`network.tf`** — Defines the virtual network, subnets, and networking resources.
- **`outputs.tf`** — Exposes useful values such as the gateway public IP and private endpoint IP.
- **`terraform.tfvars`** — Supplies local variable values. Keep credentials and secrets out of source control.
- **`.gitignore`** — Excludes generated files, local state, and sensitive configuration files from Git.
- **`application_gateway.tf`** — application gateway configuration file

The exact distribution of resources between `main.tf` and `network.tf` may evolve as the project grows.

## 5. Prerequisites

Before deploying the infrastructure, ensure the following are available:

- An Azure subscription.
- Azure CLI installed and authenticated.
- Terraform installed.
- Git installed.
- Appropriate Azure permissions to create networking and compute resources.
- A valid PFX certificate and password for the Application Gateway HTTPS listener.
- Terraform variables configured for the intended subscription, resource names, region, and other settings.

Authenticate to Azure:

```powershell
az login
az account show
```

Select the intended subscription if necessary:

```powershell
az account set --subscription "<SUBSCRIPTION_ID>"
```

Verify Terraform:

```powershell
terraform version
```

Never commit subscription secrets, certificate passwords, private keys, Terraform state files, or sensitive `.tfvars` files to a public repository.

## 6. Deployment Workflow

Run the following commands from the project directory.

### Step 1 — Initialize Terraform

```powershell
terraform init
```

Downloads the required providers and initializes the working directory.

### Step 2 — Format the configuration

```powershell
terraform fmt -recursive
```

Formats Terraform files consistently.

### Step 3 — Validate the configuration

```powershell
terraform validate
```

Checks whether the Terraform configuration is syntactically valid and internally consistent.

### Step 4 — Review the deployment plan

```powershell
terraform plan -out=tfplan
```

Review the resources Terraform intends to create, modify, or destroy before proceeding.

### Step 5 — Apply the configuration

```powershell
terraform apply tfplan
```

Creates or updates the Azure infrastructure according to the saved plan.

### Step 6 — Review outputs

```powershell
terraform output
```

Use the outputs to identify the gateway public IP, private endpoint IP, and application hostname where configured.

### Step 7 — Inspect deployed resources

Use the Azure portal or Azure CLI to confirm that resources are provisioned successfully and that the Application Gateway backend health is reported as healthy.

## 7. Connectivity and Validation Tests

The lab was tested on October 13, 2026.

### Test 1 — App Service private DNS resolution

**Objective:** Verify that the App Service hostname resolves to the private endpoint address from the Linux test VM.

Expected command:

```bash
nslookup app-azlab-web.azurewebsites.net
```

Observed result:

```text
Resolved address: 10.10.3.4
```

**Result: PASS**

The hostname resolved to the private endpoint IP address. This validates private DNS resolution from the test VM.

### Test 2 — Access the App Service through its private endpoint

**Objective:** Confirm that the test VM can reach the App Service using its hostname.

```bash
curl -I https://app-azlab-web.azurewebsites.net
```

Observed result: HTTP 200.

**Result: PASS**

The test VM successfully reached the App Service through the private endpoint path.

### Test 3 — Direct public App Service access

**Objective:** Check whether the App Service is accessible through its public hostname.

Observed result: HTTP 403 when accessing the App Service directly through its public endpoint.

**Result: PASS for the intended access restriction**

The public endpoint rejected the tested request. This is consistent with the goal of restricting direct public access to the App Service.

Note: An HTTP 403 alone does not identify the exact policy responsible. Confirm the App Service networking settings and access restrictions to establish why the request was rejected.

### Test 4 — Application Gateway backend health

**Objective:** Confirm that the gateway can reach the App Service backend.

Observed result: The backend was reported as **Healthy**.

**Result: PASS**

The gateway's health probe was able to validate the configured backend according to its probe settings.

### Test 5 — Access the application through Application Gateway

**Objective:** Validate the public gateway-to-backend traffic path.

Observed result: The gateway endpoint returned HTTP 200 and displayed the App Service default welcome page.

**Result: PASS, with a certificate-validation caveat**

Certificate validation was bypassed during the test. Therefore, the result confirms application reachability and an HTTP response, but does not establish that the certificate is trusted or that hostname validation is correct.

For a production-ready test, use a certificate trusted by the client and verify the intended DNS hostname without disabling certificate validation.

### Test 6 — Outbound internet connectivity from the Linux VM

**Objective:** Verify that the VM can establish an outbound HTTPS connection.

Tested destination: Google over HTTPS.

Observed result: The outbound HTTPS test succeeded.

**Result: PASS**

This confirms outbound connectivity for the tested destination. It does not prove that all outbound destinations or protocols are allowed.

### Test summary

| Test | Result |
|---|---|
| Private DNS resolution | PASS |
| VM to App Service over private endpoint | PASS |
| Direct public App Service request rejected | PASS for intended restriction |
| Application Gateway backend health | PASS |
| Gateway endpoint returns HTTP 200 | PASS; certificate validation bypassed |
| VM outbound HTTPS connectivity | PASS |

## 8. App Service VNet Integration vs. Private Endpoint

These two features serve different purposes and should not be confused.

### App Service VNet integration

- Allows the App Service to make outbound connections into a virtual network.
- Can be used to reach supported private resources such as internal APIs, databases, or VMs.
- Uses a designated integration subnet.

### App Service Private Endpoint

- Provides a private inbound access path from the virtual network to the App Service.
- Assigns a private IP address to the endpoint.
- Uses private DNS to direct clients to that private address.

In this lab, the VM-to-App-Service test validates the private endpoint and DNS path.

A separate test is needed to prove App Service VNet integration. For example, the web application can attempt to reach a test service available only inside the VNet, and the result can be checked through application logs or an appropriate connectivity test.

## 9. Security Considerations

- Use HTTPS for both client-to-gateway and gateway-to-backend traffic.
- Use a trusted TLS certificate for the intended production hostname.
- Protect the certificate's private key and password.
- Disable direct public App Service access when the design requires the gateway to be the only public entry point.
- Confirm private DNS resolution from the relevant network context.
- Keep the Application Gateway in a dedicated subnet.
- Use least-privilege Azure permissions.
- Avoid storing credentials and secrets in Git.
- Review Azure resource costs before deploying or leaving the lab running.

A private endpoint does not automatically disable public App Service access. Public access restrictions must be configured and tested separately.

## 10. Troubleshooting Notes

### App Service resolves to a public IP instead of the private endpoint

Check:

- The private DNS zone `privatelink.azurewebsites.net`.
- The DNS A record for the App Service.
- The virtual network link for the private DNS zone.
- DNS configuration and resolution from the test machine.

### Application Gateway backend is unhealthy

Check:

- The backend FQDN.
- Private DNS resolution from the gateway's network context.
- Private endpoint approval and connectivity.
- Backend HTTPS port 443.
- The health probe hostname and path.
- The probe's expected HTTP status codes.
- App Service networking and access restrictions.
- TLS certificate and hostname compatibility.

### Direct public App Service requests return HTTP 403

Check the App Service networking configuration and access restrictions to identify which policy is rejecting the request.

### Terraform plans unexpected resource changes

Run:

```powershell
terraform plan
```

Review the proposed changes carefully before applying. Check the current Azure resource configuration, Terraform variables, state, and code for discrepancies.

Do not apply a plan that unexpectedly destroys or replaces important resources without understanding why.

## 11. Cost Management and Cleanup

Application Gateway and virtual machines can generate ongoing costs even when they are not actively used.

After completing lab exercises, remove the infrastructure when it is no longer required.

From the project directory:

```powershell
terraform plan -destroy
```

Review the proposed destruction. If the resources are safe to remove:

```powershell
terraform destroy
```

**Important:** Terraform state must correspond to the infrastructure being destroyed. Confirm the subscription, workspace, state file, and planned resources before proceeding.

Destroying the lab removes the managed infrastructure and may release its public IP address. Save useful screenshots, test results, and documentation before cleanup.

## 12. Lessons Learned

This lab helped reinforce the following Azure architecture concepts:

1. How Terraform provisions Azure resources using reusable variables and resource references.
2. How a virtual network and dedicated subnets support application architecture.
3. The difference between App Service VNet integration and private endpoints.
4. How private DNS maps an App Service hostname to a private endpoint IP.
5. How Application Gateway provides a public entry point for HTTPS traffic.
6. How listeners, certificates, backend pools, health probes, backend settings, and routing rules work together.
7. How to validate private connectivity, public access restrictions, backend health, and outbound network access.
8. Why successful resource deployment does not automatically prove end-to-end connectivity.
9. Why certificate validation and public access restrictions must be tested explicitly.
10. How Terraform plan, apply, outputs, and destroy support the infrastructure lifecycle.

## 13. Future Improvements

Potential improvements for a future iteration:

- Validate App Service VNet integration with an explicit outbound-to-private-resource test.
- Configure a trusted TLS certificate and test the gateway hostname without bypassing certificate validation.
- Document the exact VNet address space and CIDR ranges for each subnet.
- Add more useful Terraform outputs and resource tags.
- Evaluate Application Gateway Web Application Firewall (WAF) capabilities.
- Add a dedicated application health endpoint.
- Add monitoring and diagnostic settings for the gateway and App Service.
- Evaluate secure secret management for certificate material.
- Add a deployment diagram and screenshots of backend health and connectivity tests.
- Review the design against Azure Well-Architected Framework principles.

## 14. Project Status

**Core infrastructure deployed and connectivity tested.**

The lab has demonstrated private endpoint access from the Linux test VM, private DNS resolution, a healthy Application Gateway backend, successful access through the gateway, rejection of the tested direct public App Service request, and outbound HTTPS connectivity from the VM.

Remaining validation includes a dedicated test for App Service VNet integration and full certificate and hostname validation for the public gateway endpoint.

---

**Repository:** `Terraform-Azure -Lab/01-secure-web-app`

