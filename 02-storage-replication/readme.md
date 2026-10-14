# Lab 02: Azure Storage Geo-Replication Testing with RA-GRS

## Overview

This lab demonstrates how to deploy an Azure Storage account with Read-Access Geo-Redundant Storage (RA-GRS), upload a test file, verify that the file is accessible through the secondary Blob endpoint, and inspect Azure's reported geo-replication synchronization time.

**Focus areas:** Azure Storage, geo-replication, Terraform, Azure CLI, business continuity, and disaster recovery fundamentals.

## Objectives

- Provision Azure Storage infrastructure using Terraform.
- Understand Azure Storage redundancy and RA-GRS.
- Upload a test file to a private Blob container.
- Verify access to the secondary Blob endpoint.
- Inspect the replication configuration and Last Sync Time.
- Understand RPO and RTO and the limitations of geo-replication.
- Destroy the lab resources after testing to control costs.

## Architecture

### Resources

| Resource | Configuration |
|---|---|
| Resource group | `rg-storage-replication-lab` |
| Primary region | Canada Central |
| Storage account | `storagereptestac` |
| Account kind | StorageV2 (GPv2) |
| Performance tier | Standard |
| Access tier | Hot |
| Redundancy | RA-GRS |
| Blob container | `replication-test` |
| Container access | Private |
| Infrastructure as code | Terraform with AzureRM provider |

### Architecture flow

1. Terraform provisions the resource group, storage account, and Blob container.
2. A test file is uploaded through the primary Blob endpoint.
3. Azure asynchronously replicates storage data to a secondary region.
4. The secondary Blob endpoint provides read access because the account uses RA-GRS.
5. Azure CLI and the Azure portal are used to inspect the configuration and synchronization information.

**Important:** The secondary copy is managed by Azure. A second storage account is not created manually.

## Prerequisites

- An Azure subscription.
- Azure CLI installed.
- Terraform installed.
- An authenticated Azure CLI session.
- Permission to deploy Azure resources.
- Appropriate Blob data-plane permissions to upload or read files using Microsoft Entra ID authentication.

## Terraform deployment

Initialize and validate the Terraform configuration:

```powershell
az login
az account show --output table

terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the plan before deploying.

The reviewed plan showed:

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

The planned resources were:

- `azurerm_resource_group.lab`
- `azurerm_storage_account.lab`
- `azurerm_storage_container.test`

Deploy the resources:

```powershell
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

The deployment completed successfully, and the resources were visible in the Azure portal.

## Upload a test file

Set the resource names:

```powershell
$rg = "rg-storage-replication-lab"
$account = "storagereptestac"
$container = "replication-test"
```

Upload a small test file to the primary Blob endpoint:

```powershell
az storage blob upload `
  --account-name $account `
  --container-name $container `
  --name "replication-test.txt" `
  --file ".\replication-test.txt" `
  --auth-mode login
```

Replace the example filename and local path with the actual file used.

**Observed result:** The test file was uploaded successfully to the storage account.

## Verify redundancy and replication status

### Azure CLI

Run:

```powershell
az storage account show `
  --name $account `
  --resource-group $rg `
  --expand geoReplicationStats `
  --query "{sku:sku.name,primary:primaryLocation,secondary:secondaryLocation,status:geoReplicationStats.status,lastSyncTime:geoReplicationStats.lastSyncTime}" `
  --output json
```

The query requests:

- Storage redundancy SKU.
- Primary region.
- Secondary region.
- Secondary replication status.
- Last Sync Time.

### Azure portal

1. Open the storage account `storagereptestac`.
2. Navigate to **Data management → Redundancy**.
3. Confirm the RA-GRS configuration.
4. Record the primary and secondary regions.
5. Inspect the reported Last Sync Time and replication information.

Portal labels may vary slightly with Azure updates.

### Observed results

| Check | Result |
|---|---|
| Redundancy configuration | RA-GRS |
| Primary region | Canada Central |
| Last Sync Time | October 14, 2026, at 2:17:16 PM |
| Secondary Blob endpoint read test | Successful |

The Last Sync Time is a replication checkpoint. It is not a real-time replication progress percentage and does not guarantee the exact amount of data that would be lost during a regional failure.

## Verify secondary Blob access

Define the secondary endpoint:

```powershell
$secondaryEndpoint = "https://$account-secondary.blob.core.windows.net"
```

List blobs through the secondary endpoint:

```powershell
az storage blob list `
  --account-name $account `
  --blob-endpoint $secondaryEndpoint `
  --container-name $container `
  --auth-mode login `
  --query "[].name" `
  --output table
```

To download a test blob from the secondary endpoint:

```powershell
$blob = "replication-test.txt"

az storage blob download `
  --account-name $account `
  --blob-endpoint $secondaryEndpoint `
  --container-name $container `
  --name $blob `
  --file ".\secondary-copy.txt" `
  --auth-mode login
```

Use the actual filename uploaded during the lab.

### Authentication and permissions

During testing, Azure CLI reported insufficient permissions for a storage data operation.

The subscription-level Owner role provides broad management permissions but does not automatically grant Blob data access through Microsoft Entra ID authentication.

The **Storage Blob Data Reader** role provides read access to Blob data. A role assignment may take several minutes to propagate.

### Observed result

**Passed:** The uploaded file was successfully visible through the secondary Blob endpoint.

This confirmed that the secondary endpoint could serve the test file. It did not simulate a regional outage or prove that a complete application could recover automatically.

## RPO and RTO concepts

### Recovery Point Objective (RPO)

RPO defines how much recent data the business can tolerate losing.

Because RA-GRS uses asynchronous replication, recent writes may not yet have reached the secondary region during an incident.

The Last Sync Time helps assess potential data exposure, but it does not prove the exact amount of data that would be lost.

**Lab result:** Last Sync Time was October 14, 2026, at 2:17:16 PM. Secondary read access was successful. Actual data loss during an outage was not measured.

### Recovery Time Objective (RTO)

RTO defines how long the business can tolerate service unavailability.

Storage replication alone does not recover every application dependency. Application recovery may also require compute resources, networking, DNS changes, database recovery, and application validation.

**Lab result:** RTO was not measured because no failover or application recovery test was performed.

## Key learnings

1. RA-GRS provides geo-replication and read access to a secondary region.
2. Azure manages the secondary replica without requiring a separately deployed storage account.
3. Primary and secondary Blob endpoints are distinct.
4. Secondary endpoint access is a practical way to validate that replicated data is available.
5. Last Sync Time is a useful checkpoint but not a precise measurement of data loss.
6. RPO and RTO are business recovery objectives, not simply properties of a storage SKU.
7. Geo-replication is not a substitute for backup because unwanted changes or deletions may also be replicated.
8. Management-plane permissions and Blob data-plane permissions are separate.
9. A complete disaster recovery design must consider data protection, failover, application dependencies, and recovery testing.

## Limitations

This lab verified the storage configuration and secondary read access. It did not:

- Simulate a primary-region outage.
- Perform a customer-managed storage account failover.
- Measure actual data loss.
- Measure application recovery time.
- Validate recovery of an entire application.

## Cleanup

After documenting the results, the lab resources were destroyed to minimize ongoing costs.

Review the resources and destroy plan before cleanup:

```powershell
terraform state list
terraform plan -destroy
```

Destroy the Terraform-managed resources:

```powershell
terraform destroy
```

Confirm the deletion prompt only after reviewing the planned resources.

**Observed result:** The lab was destroyed after testing.

## Future work

- Compare LRS, ZRS, GRS, and RA-GRS.
- Review customer-managed storage account failover and its implications.
- Build an Azure Site Recovery lab for VM replication and test failover.
- Compare geo-replication with Azure Backup and point-in-time recovery.
- Develop a recovery validation checklist with measurable RPO and RTO targets.

## Conclusion

Successfully deployed an Azure Storage account using Terraform, uploaded a test file, verified secondary Blob endpoint access, and inspected the Last Sync Time.

This lab demonstrated storage-level geo-replication and its relationship to disaster recovery while highlighting the distinction between replicated data and a fully recovered service.