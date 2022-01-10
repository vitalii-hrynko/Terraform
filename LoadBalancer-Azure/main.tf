terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.64.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lb-rg" {
  name     = "LB-RG"
  location = "West Europe"
}

resource "azurerm_virtual_network" "lb-vmnet" {
  name                = "LB-Vmnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.lb-rg.location
  resource_group_name = azurerm_resource_group.lb-rg.name
}

resource "azurerm_subnet" "lb-vmnet-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.lb-rg.name
  virtual_network_name = azurerm_virtual_network.lb-vmnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "publicipforlb" {
  name                = "PublicIPForLB"
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.lb-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "lb-vmnet-nsg" {
  name                = "LB-Vmnet-NSG"
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.lb-rg.name
  security_rule {
    name                       = "http"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_lb" "lb" {
  name                = "LB"
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.lb-rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.publicipforlb.id
  }
}

resource "azurerm_lb_backend_address_pool" "backendpool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackendPool"
}

resource "azurerm_lb_probe" "lb-health-probe" {
  resource_group_name = azurerm_resource_group.lb-rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "lb-health-probe"
  port                = 80
  request_path        = "/"
  protocol            = "http"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb-rule" {
  resource_group_name            = azurerm_resource_group.lb-rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.backendpool.id
  probe_id                       = azurerm_lb_probe.lb-health-probe.id
  idle_timeout_in_minutes        = 15
  enable_tcp_reset               = true
}

resource "azurerm_network_interface" "vm1-nic" {
  name                = "VM1-nic"
  location            = azurerm_resource_group.lb-rg.location
  resource_group_name = azurerm_resource_group.lb-rg.name
  ip_configuration {
    name                          = "vm-1-configuration"
    subnet_id                     = azurerm_subnet.lb-vmnet-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "vm2-nic" {
  name                = "VM2-nic"
  location            = azurerm_resource_group.lb-rg.location
  resource_group_name = azurerm_resource_group.lb-rg.name
  ip_configuration {
    name                          = "vm-2-configuration"
    subnet_id                     = azurerm_subnet.lb-vmnet-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "sec-grp-assoc-1" {
  network_interface_id      = azurerm_network_interface.vm1-nic.id
  network_security_group_id = azurerm_network_security_group.lb-vmnet-nsg.id
}

resource "azurerm_network_interface_security_group_association" "sec-grp-assoc-2" {
  network_interface_id      = azurerm_network_interface.vm2-nic.id
  network_security_group_id = azurerm_network_security_group.lb-vmnet-nsg.id
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "VM1"
  location              = azurerm_resource_group.lb-rg.location
  resource_group_name   = azurerm_resource_group.lb-rg.name
  network_interface_ids = [azurerm_network_interface.vm1-nic.id]
  size                  = "Standard_DS1_v2"
  zone                  = 1
  admin_username        = "adminuser"
  custom_data           = file("deploy-site-httpd-1-bs64.sh")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "myosdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "VM2"
  location              = azurerm_resource_group.lb-rg.location
  resource_group_name   = azurerm_resource_group.lb-rg.name
  network_interface_ids = [azurerm_network_interface.vm2-nic.id]
  size                  = "Standard_DS1_v2"
  zone                  = 2
  admin_username        = "adminuser"
  custom_data           = file("deploy-site-httpd-2-bs64.sh")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "myosdisk2"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

}

resource "azurerm_network_interface_backend_address_pool_association" "back-pool-assoc-1" {
  network_interface_id    = azurerm_network_interface.vm1-nic.id
  ip_configuration_name   = "vm-1-configuration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "back-pool-assoc-2" {
  network_interface_id    = azurerm_network_interface.vm2-nic.id
  ip_configuration_name   = "vm-2-configuration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
}

