
# Public IP address for the Application Gateway
resource "azurerm_public_ip" "gateway_public_ip" {
  name                = var.app_gateway_public_ip_name
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name

  allocation_method = "Static"
  sku               = "Standard"
}

# Application Gateway
resource "azurerm_application_gateway" "web_gateway" {
  name                = var.app_gateway_name
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name

  sku {
    name = var.app_gateway_sku_name
    tier = var.app_gateway_sku_name
  }

  autoscale_configuration {
    min_capacity = var.app_gateway_min_capacity
    max_capacity = var.app_gateway_max_capacity
  }

  # Subnet dedicated to Application Gateway
  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.gateway_subnet.id
  }

  # Public frontend
  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.gateway_public_ip.id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  # TLS certificate for incoming HTTPS requests
  ssl_certificate {
    name     = "lab-tls-certificate"
    data     = filebase64(var.app_gateway_certificate_path)
    password = var.app_gateway_certificate_password
  }

  # HTTPS listener
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "lab-tls-certificate"
  }

  # App Service backend, addressed by its Azure hostname
  backend_address_pool {
    name  = "app-service-backend"
    fqdns = ["${var.webapp_service}.azurewebsites.net"]
  }

  # Probe the App Service over HTTPS
  probe {
    name                = "app-service-health-probe"
    protocol            = "Https"
    host                = "${var.webapp_service}.azurewebsites.net"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200-399"]
    }
  }

  # HTTPS connection from gateway to App Service
  backend_http_settings {
    name                                = "app-service-https-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    probe_name                          = "app-service-health-probe"
    pick_host_name_from_backend_address = true
  }

  # Route incoming requests to the App Service
  request_routing_rule {
    name                       = "https-routing-rule"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "app-service-backend"
    backend_http_settings_name = "app-service-https-settings"
  }

  http2_enabled = true

  # Ensure the private backend and DNS configuration exist first
  depends_on = [
    azurerm_private_endpoint.webapp_endpoint,
    azurerm_private_dns_zone_virtual_network_link.webapp_dns_link
  ]
}

