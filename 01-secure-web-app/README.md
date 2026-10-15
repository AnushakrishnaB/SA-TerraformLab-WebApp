# Azure Secure Web Application — Terraform Lab

## 1. Project Overview

This project demonstrates how to deploy and secure an Azure web application using Terraform and Azure networking services.

The goal is to make the web application accessible through Azure Application Gateway while keeping the App Service backend accessible through a private endpoint and disabling direct public access to App Service.

The infrastructure is defined using Terraform to explore Infrastructure as Code (IaC), Azure networking, private connectivity, HTTPS, DNS resolution, backend health probing, and traffic routing.

- **Project type:** Azure architecture / Infrastructure as Code
- **Cloud provider:** Microsoft Azure
- **IaC tool:** Terraform
- **Language:** HCL
- **Application platform:** Azure App Service (Linux)

## 2. Architecture

### High-level architecture

The following describes the intended traffic paths. App Service is a platform-as-a-service (PaaS) resource outside the virtual network boundary. Its private endpoint is placed inside the VNet in the dedicated endpoint subnet.

```text
                         Internet
                            |
                         HTTPS / 443
                            |
                            v
                   Azure Public IP
                            |
                            v
                 Azure Application Gateway
                 - HTTPS listener and certificate
                 - Routing rule
                 - Backend health probe
                            |
                     HTTPS / 443
                            |
                            v
                App Service Private Endpoint
                   (endpoint subnet in VNet)
                            |
                            v
                 Azure App Service (Linux)
                  Public access disabled


  Linux test VM (test subnet in VNet)
       |                         |
       | HTTPS to App Service    | Outbound HTTPS test
       v                         v
  Private Endpoint             Internet

  Private DNS zone:
  privatelink.azurewebsites.net
  (linked to the VNet)
```

The Linux test VM is used to validate private DNS resolution and access to App Service through its private endpoint. The VM's outbound HTTPS test is separate from App Service VNet Integration.

### Traffic flow

1. A user connects to the public IP address of Application Gateway.
2. The HTTPS listener accepts the connection using its configured TLS certificate.
3. The routing rule forwards the request to the App Service backend pool.
4. Application Gateway resolves the App Service hostname using the configured DNS arrangement.
5. The backend hostname resolves to the private endpoint IP address.
6. Application Gateway connects to App Service over HTTPS.
7. The configured health probe checks the backend according to its path and expected status codes.

The **Private Endpoint** provides private inbound connectivity to App Service. **App Service VNet Integration** is a separate feature that allows the application to make outbound connections into the virtual network. VNet Integration is configured in this lab, but it requires a separate outbound-to-private-resource test to validate its behavior.

## 3. Azure Resources

| Resource | Name | Purpose |
|---|---|---|
| Resource Group | `rg-azlab-web-prod` | Contains the lab resources |
| Virtual Network | `vnet-azlab-prod` | Provides private network connectivity |
| App Service integration subnet | `snet-app-prod` | Subnet delegated for App Service VNet Integration |
| Application Gateway subnet | `snet-gateway-prod` | Dedicated subnet for Application Gateway |
| Private Endpoint subnet | `snet-endpoint-prod` | Hosts the App Service private endpoint |
| Linux test VM subnet | As defined in Terraform | Provides a test location inside the VNet |
| App Service Plan | `asp-azlab-web` | Provides compute resources for the web application |
| Linux Web App | `app-azlab-web` | Hosts the web application |
| Private Endpoint | `pe-app-azlab-web` | Provides private access to App Service |
| Application Gateway | `agw-azlab-web-prod` | Provides the public HTTPS entry point and routes traffic |
| Public IP | `pip-agw-azlab-web-prod` | Provides public access to Application Gateway |
| Private DNS Zone | `privatelink.azurewebsites.net` | Supports private name resolution for App Service |
| Linux Test VM | `vm-azlab-test` | Used to test private connectivity and outbound access |

### Network addresses observed during testing

- **Private endpoint IP:** `10.10.3.4`
- **Linux test VM IP:** `10.10.4.4`
- **Application Gateway public IP observed during testing:** `4.205.12.93`
- **App Service hostname:** `app-azlab-web.azurewebsites.net`

These are observations from this lab deployment, not guaranteed permanent addresses. Recheck them after recreating the infrastructure. Document the VNet address space and each subnet's CIDR range from the actual Terraform configuration when updating this README.

## 4. Terraform Project Structure

Project directory, relative to the repository root:

`01-secure-web-app/`

Expected project files (confirm against the current directory if files are added, removed, or renamed):

```text
01-secure-web-app/
├── README.md
├── main.tf
├── network.tf
├── application_gateway.tf
├── variables.tf
├── provider.tf
├── outputs.tf
├── test_vm.tf
├── .gitignore
└── terraform.tfvars       # Local configuration; do not commit
```

File responsibilities:

- `provider.tf` — Configures Terraform and the AzureRM provider.
- `variables.tf` — Declares configurable values such as resource names, locations, SKU settings, and certificate paths.
- `main.tf` — Defines the main application and related infrastructure resources.
- `network.tf` — Defines the virtual network, subnets, private endpoint, and DNS resources.
- `application_gateway.tf` — Defines Application Gateway, its frontend, listener, backend, health probe, and routing configuration.
- `test_vm.tf` — Defines the Linux test VM and its network interface.
- `outputs.tf` — Exposes useful values, such as the gateway public IP and private endpoint IP, where configured.
- `terraform.tfvars` — Supplies local variable values. Keep credentials and secrets out of source control.
- `.gitignore` — Should exclude generated files, local state, saved plans, local variable files, and sensitive certificate material.

The exact distribution of resources across Terraform files may evolve as the project grows.

## 5. Prerequisites

Before deploying the infrastructure, ensure that you have:

- An Azure subscription.
- Azure CLI installed and authenticated.
- Terraform installed.
- Git installed.
- Appropriate Azure permissions to create networking and compute resources.
- A valid PFX certificate and password for the Application Gateway HTTPS listener.
- Terraform variables configured for the intended subscription, resource names, region, and other settings.

Authenticate to Azure:

```bash
az login
az account show
```

Select the intended subscription if necessary:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

Verify Terraform:

```bash
terraform version
```

Never commit subscription secrets, certificate passwords, private keys, Terraform state files, saved plan files, or sensitive `.tfvars` files to a public repository.

## 6. Deployment Workflow

Run these commands from the `01-secure-web-app` directory.

### Step 1 — Initialize Terraform

```bash
terraform init
```

Downloads the required providers and initializes the working directory.

### Step 2 — Format the configuration

```bash
terraform fmt -recursive
```

Formats Terraform files consistently.

### Step 3 — Validate the configuration

```bash
terraform validate
```

Checks whether the Terraform configuration is syntactically valid and internally consistent.

### Step 4 — Review the deployment plan

```bash
terraform plan -out=tfplan
```

Review the resources Terraform intends to create, modify, or destroy before proceeding. Treat saved plan files as potentially sensitive and do not commit them.

### Step 5 — Apply the configuration

```bash
terraform apply tfplan
```

Creates or updates the Azure infrastructure according to the saved plan.

### Step 6 — Review outputs

```bash
terraform output
```

Use the outputs to identify the gateway public IP, private endpoint IP, and application hostname where configured.

### Step 7 — Inspect deployed resources

Use the Azure portal or Azure CLI to confirm that resources are provisioned successfully and that Application Gateway reports the backend as healthy.

## 7. Connectivity and Validation Tests

The lab was tested on **October 13, 2026**. Results below reflect the tests performed at that time and may need to be repeated after redeployment or configuration changes.

### Test 1 — App Service private DNS resolution

**Objective:** Verify that the App Service hostname resolves to the private endpoint address from the Linux test VM.

Command:

```bash
nslookup app-azlab-web.azurewebsites.net
```

**Observed result:** Resolved address `10.10.3.4`

**Result:** PASS

The hostname resolved to the private endpoint IP address. This validates private DNS resolution from the test VM.

### Test 2 — Access App Service through its private endpoint

**Objective:** Confirm that the test VM can reach App Service using its hostname.

```bash
curl -I https://app-azlab-web.azurewebsites.net
```

**Observed result:** HTTP 200

**Result:** PASS

The test VM successfully reached App Service through the private endpoint path.

### Test 3 — Direct public App Service access

**Objective:** Check whether App Service is accessible through its public hostname.

**Observed result:** HTTP 403 when accessing App Service directly through its public endpoint.

**Result:** PASS for the intended access restriction

The tested public request was rejected, consistent with the goal of restricting direct public access to App Service. An HTTP 403 alone does not identify the exact policy responsible; confirm the App Service networking settings and access restrictions to establish why the request was rejected.

### Test 4 — Application Gateway backend health

**Objective:** Confirm that Application Gateway can reach the App Service backend.

**Observed result:** The backend was reported as Healthy.

**Result:** PASS

The configured health probe reported the backend as healthy according to its probe settings.

### Test 5 — Access the application through Application Gateway

**Objective:** Validate the public gateway-to-backend traffic path.

**Observed result:** The gateway endpoint returned HTTP 200 and displayed the App Service default welcome page.

**Result:** PASS, with a certificate-validation caveat

Certificate validation was bypassed during the test. Therefore, this confirms application reachability and an HTTP response, but does not establish that the certificate is trusted or that hostname validation is correct.

For a production-oriented test, use a certificate trusted by the client and verify the intended gateway DNS hostname without disabling certificate validation.

### Test 6 — Outbound internet connectivity from the Linux VM

**Objective:** Verify that the VM can establish an outbound HTTPS connection.

**Tested destination:** Google over HTTPS.

**Observed result:** The outbound HTTPS test succeeded.

**Result:** PASS

This confirms outbound connectivity for the tested destination from the Linux VM. It does not prove that all outbound destinations or protocols are allowed, and it does not validate App Service VNet Integration.

### Test summary

| Test | Result |
|---|---|
| Private DNS resolution from test VM | PASS |
| Test VM to App Service through private endpoint | PASS |
| Tested direct public App Service request rejected | PASS for intended restriction |
| Application Gateway backend health | PASS |
| Gateway endpoint returns HTTP 200 | PASS; certificate validation was bypassed |
| Test VM outbound HTTPS connectivity | PASS |
| App Service VNet Integration to a private resource | Not yet tested |
| Trusted certificate and gateway hostname validation | Not yet validated |

## 8. App Service VNet Integration vs. Private Endpoint

These features serve different purposes and should not be confused.

### App Service VNet Integration

- Allows App Service to make outbound connections into a virtual network.
- Can be used to reach supported private resources such as internal APIs, databases, or VMs.
- Uses a designated integration subnet.

### App Service Private Endpoint

- Provides a private inbound access path from the virtual network to App Service.
- Assigns a private IP address to the endpoint.
- Uses private DNS to direct clients to that private address.

In this lab, the VM-to-App-Service test validates the private endpoint and DNS path. A separate test is needed to validate App Service VNet Integration. For example, the web application could attempt to reach a test service available only inside the VNet, with the result confirmed through application logs or an appropriate connectivity test.

## 9. Security Considerations

- Use HTTPS for both client-to-gateway and gateway-to-backend traffic.
- Use a trusted TLS certificate for the intended gateway hostname and validate the backend TLS configuration.
- Protect certificate private keys and passwords.
- Disable direct public App Service access when the design requires Application Gateway to be the only public entry point.
- Confirm private DNS resolution from the relevant network context.
- Keep Application Gateway in a dedicated subnet.
- Use least-privilege Azure permissions.
- Avoid storing credentials and secrets in Git.
- Review Azure resource costs before deployment and while the lab is running.

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
- Private DNS resolution from Application Gateway's network context.
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

```bash
terraform plan
```

Review the proposed changes carefully before applying. Check the current Azure resource configuration, Terraform variables, state, and code for discrepancies.

Do not apply a plan that unexpectedly destroys or replaces important resources without understanding why.

## 11. Cost Management and Cleanup

Application Gateway and virtual machines can generate ongoing costs even when they are not actively used.

After completing lab exercises, remove the infrastructure when it is no longer required.

From the project directory:

```bash
terraform plan -destroy
```

Review the proposed destruction. If the resources are safe to remove:

```bash
terraform destroy
```

**Important:** Terraform state must correspond to the infrastructure being destroyed. Confirm the subscription, workspace, state file, and planned resources before proceeding.

Destroying the lab removes the managed infrastructure and may release its public IP address. Save useful screenshots, test results, and documentation before cleanup.

## 12. Lessons Learned

This lab helped reinforce the following Azure architecture concepts:

1. How Terraform provisions Azure resources using variables and resource references.
2. How a virtual network and dedicated subnets support an application architecture.
3. The difference between App Service VNet Integration and private endpoints.
4. How private DNS maps an App Service hostname to a private endpoint IP.
5. How Application Gateway provides a public entry point for HTTPS traffic.
6. How listeners, certificates, backend pools, health probes, backend settings, and routing rules work together.
7. How to validate private connectivity, public access restrictions, backend health, and outbound network access.
8. Why successful resource deployment does not automatically prove end-to-end connectivity.
9. Why certificate validation and public access restrictions must be tested explicitly.
10. How Terraform plan, apply, outputs, and destroy support the infrastructure lifecycle.

<<<<<<< Updated upstream
### Potential Improvements for a Future Iteration
=======
## 13. Potential Improvements for a Future Iteration
>>>>>>> Stashed changes

The following improvements could strengthen the security, availability, monitoring, and operational readiness of this lab for a production scenario:

- **Security:** Evaluate Application Gateway WAF policies, trusted end-to-end TLS certificate validation, secure certificate management with Azure Key Vault, and restrictive Network Security Group (NSG) rules.
- **High availability:** Evaluate zone-redundant App Service hosting, multiple instances, and Application Gateway availability-zone configuration.
<<<<<<< Updated upstream
- **Connectivity validation:** Add an explicit outbound connectivity test from App Service to a private resource to validate VNet integration.
- **Application health:** Implement a dedicated application health endpoint and validate health probe behavior.
- **Monitoring and diagnostics:** Configure Azure Monitor, diagnostic settings, application monitoring, and alerts for Application Gateway and App Service.
- **Identity and governance:** Evaluate managed identities, least-privilege access, and Azure Policy.
- **Terraform improvements:** Document VNet address spaces and subnet CIDR ranges, improve outputs and resource tagging, and review infrastructure configuration for maintainability.
- **Documentation and testing:** Add deployment diagrams, screenshots of backend health and connectivity tests, and documented validation results.
- **Architecture review:** Assess the design against Azure Well-Architected Framework principles, particularly security, reliability, operational excellence, performance efficiency, and cost optimization.

These items are future design considerations, not outstanding requirements for this cost-conscious learning lab. They have not necessarily been implemented or validated, and would be evaluated based on production requirements, service support, and cost.
=======
- **Connectivity validation:** Add an explicit outbound connectivity test from App Service to a private resource to validate VNet Integration.
- **Application health:** Implement a dedicated application health endpoint and validate health probe behavior.
- **Monitoring and diagnostics:** Configure Azure Monitor, diagnostic settings, application monitoring, and alerts for Application Gateway and App Service.
- **Identity and governance:** Evaluate managed identities, least-privilege access, and Azure Policy.
- **Terraform improvements:** Document the VNet address space and subnet CIDR ranges from the actual configuration, improve outputs and resource tags, and review configuration maintainability.
- **Documentation and testing:** Improve the architecture diagram and add screenshots of backend health and connectivity tests where useful.
- **Architecture review:** Assess the design against Azure Well-Architected Framework principles: reliability, security, cost optimization, operational excellence, and performance efficiency.

These are future design considerations, not outstanding requirements for this cost-conscious learning lab. They have not necessarily been implemented or validated and would be evaluated against production requirements, service support, and cost.

**Reference architecture:** [Microsoft Learn — Baseline Highly Available Zone-Redundant App Service Architecture](https://learn.microsoft.com/en-us/azure/architecture/web-apps/app-service/architectures/baseline-zone-redundant)
>>>>>>> Stashed changes

## 14. Project Status

**Status:** Core infrastructure deployed and key connectivity paths tested.

The lab has demonstrated private endpoint access from the Linux test VM, private DNS resolution, a healthy Application Gateway backend, successful access through the gateway, rejection of the tested direct public App Service request, and outbound HTTPS connectivity from the VM.

Remaining validation includes a dedicated test for App Service VNet Integration and full certificate and hostname validation for the public gateway endpoint.

---

**Repository:** [`cloud-solution-architecture-portfolio/01-secure-web-app`](https://github.com/AnushakrishnaB/cloud-solution-architecture-portfolio/tree/main/01-secure-web-app)
