resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    purpose     = "storage-replication-learning"
    environment = "lab"
  }
}

resource "azurerm_storage_account" "lab" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.replication_type

  access_tier                     = "Hot"
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = {
    purpose     = "storage-replication-learning"
    environment = "lab"
  }
}

resource "azurerm_storage_container" "test" {
  name                  = "replication-test"
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}
