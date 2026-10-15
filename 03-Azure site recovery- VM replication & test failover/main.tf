###This creates the source VM, a simple Nginx test page, and the recovery and isolated test networks.

resource "azurerm_resource_group" "lab" {
  name     = "rg-asr-lab"
  location = var.location

  tags = {
    environment = "lab"
    purpose     = "site-recovery-learning"
  }
}


resource "azurerm_resource_group" "recovery" {
  name     = "rg-asr-recovery"
  location = "Canada East"

  tags = {
    environment = "lab"
    purpose     = "asr-recovery"
  }
}

resource "azurerm_virtual_network" "source" {
  name                = "vnet-asr-source"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "source" {
  name                 = "snet-source"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.source.name
  address_prefixes     = ["10.30.1.0/24"]
}

resource "azurerm_network_security_group" "source" {
  name                = "nsg-asr-source"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-SSH-From-My-IP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "source" {
  subnet_id                 = azurerm_subnet.source.id
  network_security_group_id = azurerm_network_security_group.source.id
}

resource "azurerm_public_ip" "source" {
  name                = "pip-asr-source"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "source" {
  name                = "nic-asr-source"
  location            = var.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.source.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.source.id
  }
}

resource "azurerm_linux_virtual_machine" "source" {
  name                = "vm-asr-source"
  computer_name       = "vm-asr-source"
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.location
  size                = "Standard_B1ms"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.source.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-asr-source"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - bash -c 'echo "Azure Site Recovery Lab - Source VM" > /var/www/html/index.html'
      - systemctl enable nginx
      - systemctl restart nginx
  CLOUDINIT
  )

  depends_on = [
    azurerm_subnet_network_security_group_association.source
  ]

  tags = {
    environment = "lab"
    purpose     = "site-recovery-source"
  }
}

resource "azurerm_virtual_network" "recovery" {
  name                = "vnet-asr-recovery"
  location            = var.target_location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_subnet" "recovery" {
  name                 = "snet-recovery"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.recovery.name
  address_prefixes     = ["10.40.1.0/24"]
}

resource "azurerm_virtual_network" "test" {
  name                = "vnet-asr-test"
  location            = var.target_location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "test" {
  name                 = "snet-asr-test"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.50.1.0/24"]
}


###Add the cache storage account for ASR replication.Site Recovery needs a source-region cache storage account for replication data.
resource "azurerm_storage_account" "asr_cache" {
  name                     = var.cache_storage_account_name
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = {
    environment = "lab"
    purpose     = "site-recovery-cache"
  }
}

###Create Recoverty Services Vault for ASR. This is required for the replication to work.
resource "azurerm_recovery_services_vault" "asr" {
  name                = "rsv-asr-lab-cae"
  location            = var.target_location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"

  tags = {
    environment = "lab"
    purpose     = "site-recovery-learning"
  }
}

###Create the Site Recovery fabrics and protection containers.These resources represent the source and recovery regions within the vault. AzureRM supports both fabrics and protection containers
resource "azurerm_site_recovery_fabric" "source" {
  name                = "fabric-canadacentral"
  resource_group_name = azurerm_resource_group.lab.name
  recovery_vault_name = azurerm_recovery_services_vault.asr.name
  location            = var.location
}

resource "azurerm_site_recovery_fabric" "recovery" {
  name                = "fabric-canadaeast"
  resource_group_name = azurerm_resource_group.lab.name
  recovery_vault_name = azurerm_recovery_services_vault.asr.name
  location            = var.target_location
}

resource "azurerm_site_recovery_protection_container" "source" {
  name                 = "container-source"
  resource_group_name  = azurerm_resource_group.lab.name
  recovery_vault_name  = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name = azurerm_site_recovery_fabric.source.name
}

resource "azurerm_site_recovery_protection_container" "recovery" {
  name                 = "container-recovery"
  resource_group_name  = azurerm_resource_group.lab.name
  recovery_vault_name  = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name = azurerm_site_recovery_fabric.recovery.name
}

###Create the replication policy and container mapping.We'll configure 24-hour recovery-point retention and a four-hour application-consistent snapshot interval for this learning lab.
resource "azurerm_site_recovery_replication_policy" "asr" {
  name                = "policy-asr-lab"
  resource_group_name = azurerm_resource_group.lab.name
  recovery_vault_name = azurerm_recovery_services_vault.asr.name

  recovery_point_retention_in_minutes                  = 24 * 60
  application_consistent_snapshot_frequency_in_minutes = 4 * 60
}

resource "azurerm_site_recovery_protection_container_mapping" "asr" {
  name                                      = "mapping-asr-lab"
  resource_group_name                       = azurerm_resource_group.lab.name
  recovery_vault_name                       = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.source.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.source.name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.recovery.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.asr.id
}

###The container mapping connects the source protection container to the recovery container and applies the replication policy.

###Create the network mapping.This tells Site Recovery which recovery VNet corresponds to the source VNet.
resource "azurerm_site_recovery_network_mapping" "asr" {
  name                        = "network-mapping-asr-lab"
  resource_group_name         = azurerm_resource_group.lab.name
  recovery_vault_name         = azurerm_recovery_services_vault.asr.name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.source.name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.recovery.name

  source_network_id = azurerm_virtual_network.source.id
  target_network_id = azurerm_virtual_network.recovery.id
}

###Configure replication for the source VM.First, add a data source to look up the VM's managed OS disk after the VM is created:
data "azurerm_managed_disk" "source_os" {
  name                = azurerm_linux_virtual_machine.source.os_disk[0].name
  resource_group_name = azurerm_resource_group.lab.name

  depends_on = [
    azurerm_linux_virtual_machine.source
  ]
}

###Now add the replicated VM resource. The AzureRM resource supports the source VM, target region, replicated disks, recovery network, and test network.
resource "azurerm_site_recovery_replicated_vm" "source" {
  name                                      = "replicated-vm-asr-source"
  resource_group_name                       = azurerm_resource_group.lab.name
  recovery_vault_name                       = azurerm_recovery_services_vault.asr.name
  source_recovery_fabric_name               = azurerm_site_recovery_fabric.source.name
  source_vm_id                              = azurerm_linux_virtual_machine.source.id
  source_recovery_protection_container_name = azurerm_site_recovery_protection_container.source.name
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.asr.id

  target_resource_group_id                = azurerm_resource_group.recovery.id
  target_recovery_fabric_id               = azurerm_site_recovery_fabric.recovery.id
  target_recovery_protection_container_id = azurerm_site_recovery_protection_container.recovery.id

  target_network_id = azurerm_virtual_network.recovery.id
  test_network_id   = azurerm_virtual_network.test.id

  managed_disk {
    disk_id                    = data.azurerm_managed_disk.source_os.id
    staging_storage_account_id = azurerm_storage_account.asr_cache.id
    target_resource_group_id   = azurerm_resource_group.recovery.id
    target_disk_type           = "Standard_LRS"
    target_replica_disk_type   = "Standard_LRS"
  }

  network_interface {
    source_network_interface_id = azurerm_network_interface.source.id
    target_subnet_name          = azurerm_subnet.recovery.name
    failover_test_subnet_name   = azurerm_subnet.test.name
  }

  depends_on = [
    azurerm_site_recovery_protection_container_mapping.asr,
    azurerm_site_recovery_network_mapping.asr
  ]
}
