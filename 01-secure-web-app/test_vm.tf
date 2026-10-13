
# Network interface for the test VM
resource "azurerm_network_interface" "test_vm_nic" {
  name                = "nic-azlab-test-vm"
  location            = azurerm_resource_group.prod_rg.location
  resource_group_name = azurerm_resource_group.prod_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test_vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Temporary Ubuntu test VM
resource "azurerm_linux_virtual_machine" "test_vm" {
  name                = "vm-azlab-test"
  computer_name       = "azlab-test"
  resource_group_name = azurerm_resource_group.prod_rg.name
  location            = azurerm_resource_group.prod_rg.location
  size                = "Standard_B1s"

  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.test_vm_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand("~/.ssh/azlab-test-vm.pub"))
  }

  os_disk {
    name                 = "osdisk-azlab-test-vm"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Ensure the VM is created only after its subnet and NIC exist.
  depends_on = [
    azurerm_subnet.test_vm_subnet
  ]
}
