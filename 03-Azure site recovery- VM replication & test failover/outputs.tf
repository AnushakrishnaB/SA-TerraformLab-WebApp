output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "source_vm_name" {
  value = azurerm_linux_virtual_machine.source.name
}

output "source_public_ip" {
  value = azurerm_public_ip.source.ip_address
}

output "recovery_vnet_name" {
  value = azurerm_virtual_network.recovery.name
}

output "test_vnet_name" {
  value = azurerm_virtual_network.test.name
}
