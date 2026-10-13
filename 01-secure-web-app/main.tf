resource "azurerm_resource_group" "prod_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_service_plan" "webapp_plan" {
  name                = var.webapp_plan
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name

  os_type  = "Linux"
  sku_name = var.app_service_sku

}


resource "azurerm_linux_web_app" "webapp_service" {
  name                = var.webapp_service
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  service_plan_id     = azurerm_service_plan.webapp_plan.id

  site_config {
    always_on = false
  }
  https_only                                     = true
  public_network_access_enabled                  = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  client_certificate_enabled                     = false
}



