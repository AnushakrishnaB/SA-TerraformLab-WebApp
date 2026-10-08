resource "azurerm_virtual_network" "prod_vnet" {
  name                = var.networks["prod_vnet"]["name"]
  address_space       = var.networks["prod_vnet"]["addspace"]
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = var.networks["app_subnet"]["name"]
  address_prefixes     = var.networks["app_subnet"]["addspace"]
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = var.networks["gateway_subnet"]["name"]
  address_prefixes     = var.networks["gateway_subnet"]["addspace"]
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
}

resource "azurerm_subnet" "endpoint_subnet" {
  name                 = var.networks["endpoint_subnet"]["name"]
  address_prefixes     = var.networks["endpoint_subnet"]["addspace"]
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
}

resource "azurerm_app_service_virtual_network_swift_connection" "webapp_vnet_integration" {
  app_service_id = azurerm_linux_web_app.webapp_service.id
  subnet_id      = azurerm_subnet.app_subnet.id
}

data "azurerm_subnet" "app" {
  name                 = var.app_subnet_name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
  resource_group_name  = azurerm_resource_group.prod_rg.name
}
