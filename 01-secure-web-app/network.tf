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

  delegation {
    name = "app-service-delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

###Note: What delegation block does: It authorizes Azure App Service to use this subnet for VNet integration. The subnet must also meet Azure's address-space and delegation requirements.

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

### Private Endpoint for the App Service and its connection. It connects to web app and uses the sites subresource, which is the App service private endpoint target. 
### Azure will assign a private IP address to the endpoint. 
resource "azurerm_private_endpoint" "webapp_endpoint" {
  name                = "pe-${var.webapp_service}"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name
  subnet_id           = azurerm_subnet.endpoint_subnet.id

  private_service_connection {
    name                           = "psc-${var.webapp_service}"
    private_connection_resource_id = azurerm_linux_web_app.webapp_service.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name = "default"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.webapp_private_dns.id
    ]
  }
}

#### Private DNS Zone for the App Service Private Endpoint. It allows resolution of the private endpoint's IP address within the VNet. This creates the private DNS zone privatelink.azurewebsites.net.
resource "azurerm_private_dns_zone" "webapp_private_dns" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.prod_rg.name
}

#### Link the DNS zone to the VNet. This allows resources in the VNet to resolve the private endpoint's DNS name to its private IP address.
###This link allows clients using the linked VNet's DNS resolution path to resolve records from the private zone.

resource "azurerm_private_dns_zone_virtual_network_link" "webapp_dns_link" {
  name                  = "link-${var.networks["prod_vnet"]["name"]}"
  resource_group_name   = azurerm_resource_group.prod_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.webapp_private_dns.name
  virtual_network_id    = azurerm_virtual_network.prod_vnet.id
  registration_enabled  = false
}


# Dedicated subnet for the temporary Linux test VM
resource "azurerm_subnet" "test_vm_subnet" {
  name                 = var.networks["test_vm_subnet"]["name"]
  address_prefixes     = var.networks["test_vm_subnet"]["addspace"]
  resource_group_name  = azurerm_resource_group.prod_rg.name
  virtual_network_name = azurerm_virtual_network.prod_vnet.name
}



