terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.18.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "***"
  client_id       = "***"
  client_secret   = "***"
  tenant_id       = "***"
  features {}
}

locals {
  resource_group="test-grp"
  location="West US 3"
}

resource "azurerm_resource_group" "test-grp"{
  name=local.resource_group
  location=local.location
}

resource "azurerm_virtual_network" "test_network" {
  name                = "test-network"
  location            = local.location
  resource_group_name = local.resource_group
  address_space       = ["10.0.0.0/16"]  
  depends_on = [
    azurerm_resource_group.test-grp
  ]
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.test_network.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [
    azurerm_virtual_network.test_network
  ]
}

resource "azurerm_network_interface" "app_interface1" {
  name                = "app-interface1"
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
  }

  depends_on = [
    azurerm_virtual_network.test_network,
    azurerm_subnet.SubnetA
  ]
}

resource "azurerm_network_interface" "app_interface2" {
  name                = "app-interface2"
  location            = azurerm_resource_group.test-grp.location
  resource_group_name = azurerm_resource_group.test-grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
  }

  depends_on = [
    azurerm_virtual_network.test_network,
    azurerm_subnet.SubnetA
  ]
}

resource "azurerm_windows_virtual_machine" "test-vm1" {
  name                = "test-vm1"
  resource_group_name = azurerm_resource_group.test-grp.name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = "Azure@123"
  zone = 1
  network_interface_ids = [
    azurerm_network_interface.app_interface1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface1
  ]
}

resource "azurerm_windows_virtual_machine" "test-vm2" {
  name                = "test-vm2"
  resource_group_name = local.resource_group
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = "Azure@123"
  zone = 2
  network_interface_ids = [
    azurerm_network_interface.app_interface2.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface2
  ]
}

resource "azurerm_storage_account" "teststore" {
  name = "teststore2234"
  resource_group_name = local.resource_group
  location = local.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "testcontainer" {
  name = "testcontainer"
  storage_account_name = "teststore2234"
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.teststore
  ]
}

resource "azurerm_storage_blob" "IIS_config" {
  name = "IIS_Config.ps1"
  storage_account_name = "teststore2234"
  storage_container_name = "testcontainer"
  type = "Block"
  source = "IIS_Config.ps1"
  depends_on = [
    azurerm_storage_container.testcontainer
  ]
}

resource "azurerm_virtual_machine_extension" "vm_extension1" {
  name = "vm-extension1"
  virtual_machine_id = azurerm_windows_virtual_machine.test-vm1.id
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.IIS_config
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.teststore.name}.blob.core.windows.net/testcontainer/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "vm_extension2" {
  name = "vm-extension1"
  virtual_machine_id = azurerm_windows_virtual_machine.test-vm2.id
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.IIS_config
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.teststore.name}.blob.core.windows.net/testcontainer/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    }
SETTINGS
}

resource "azurerm_network_security_group" "test_nsg" {
  name = "test_nsg"
  location = local.location
  resource_group_name = local.resource_group
  
  security_rule {
    name = "Allow_HTTP"
    priority = 200
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.test_nsg.id
  depends_on = [
    azurerm_network_security_group.test_nsg
  ]
}

resource "azurerm_public_ip" "load_ip" {
  name = "load-ip"
  location = local.location
  resource_group_name = local.resource_group
  allocation_method = "Static" 
  sku = "Standard"
}

resource "azurerm_lb" "test_balancer" {
  name = "test-balancer"
  location = local.location
  resource_group_name = local.resource_group
  
  frontend_ip_configuration {
    name = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.load_ip.id
  }
  sku = "Standard"
  depends_on = [
    azurerm_public_ip.load_ip
  ]
}

resource "azurerm_lb_backend_address_pool" "PoolA" {
  loadbalancer_id = azurerm_lb.test_balancer.id
  name = "PoolA"

  depends_on = [
    azurerm_lb.test_balancer
  ]
}

resource "azurerm_lb_backend_address_pool_address" "test_vm1_address" {
  name = "testvm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id = azurerm_virtual_network.test_network.id
  ip_address = azurerm_network_interface.app_interface1.private_ip_address
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}

resource "azurerm_lb_backend_address_pool_address" "test_vm2_address" {
  name = "testvm2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id = azurerm_virtual_network.test_network.id
  ip_address = azurerm_network_interface.app_interface2.private_ip_address
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}

resource "azurerm_lb_probe" "ProbeA" {
  # resource_group_name = local.resource_group
  loadbalancer_id = azurerm_lb.test_balancer.id
  name = "ProbeA"
  port = 80
  depends_on = [
    azurerm_lb.test_balancer
  ]
}

resource "azurerm_lb_rule" "RuleA" {
  # resource_group_name = local.resource_group
  loadbalancer_id = azurerm_lb.test_balancer.id
  name = "RuleA"
  protocol = "Tcp"
  frontend_port = 80
  backend_port = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.PoolA.id]
  probe_id = azurerm_lb_probe.ProbeA.id
  depends_on = [
    azurerm_lb.test_balancer,
    azurerm_lb_probe.ProbeA
  ]
}
