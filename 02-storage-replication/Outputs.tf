output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  value = azurerm_storage_account.lab.name
}

output "replication_type" {
  value = azurerm_storage_account.lab.account_replication_type
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.lab.primary_blob_endpoint
}

output "container_name" {
  value = azurerm_storage_container.test.name
}
