
output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.gateway_public_ip.ip_address
}

output "app_service_private_endpoint_ip" {
  description = "Private IP address assigned to the App Service private endpoint"
  value       = azurerm_private_endpoint.webapp_endpoint.private_service_connection[0].private_ip_address
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.webapp_service.default_hostname
}


output "test_vm_private_ip" {
  description = "Private IP address of the temporary Linux test VM"
  value       = azurerm_network_interface.test_vm_nic.private_ip_address
}
