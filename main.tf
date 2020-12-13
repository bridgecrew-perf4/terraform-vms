terraform {
  required_version = ">= 0.13"
}

provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you're using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rgs" {
  name     = "${var.resource_prefix}_resources"
  location = var.node_location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet_01"
  resource_group_name = azurerm_resource_group.rgs.name
  location            = var.node_location
  address_space       = var.node_address_space
}

# Create a subnets within the virtual network
resource "azurerm_subnet" "subnet" {
  count                = length(var.subnet_name)
  name                 = var.subnet_name[count.index]
  resource_group_name  = azurerm_resource_group.rgs.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = var.subnet_cidr[count.index]
}

# Crate Availability Set
resource "azurerm_availability_set" "avs" {
  name                         = "avs_01"
  resource_group_name          = azurerm_resource_group.rgs.name
  location                     = azurerm_resource_group.rgs.location
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
}

# Create Public IPs
#resource "azurerm_public_ip" "public_ip" {
#  count               = var.node_count
#  name                = "pip_${format("%02d", count.index)}"
#  location            = azurerm_resource_group.rgs.location
#  resource_group_name = azurerm_resource_group.rgs.name
#  allocation_method   = "Static"
#  sku                 = "Standard"
#}

# Create Public IP for Public Load Balancer
resource "azurerm_public_ip" "public_ip_plb" {
  name                = "pip_00"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Public IP for TEST NODE
resource "azurerm_public_ip" "public_ip_vm_04" {
  name                = "pip_04"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_network_interface" "nic_01" {
  count               = var.total_node_count
  name                = "nic_01_${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name
  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = element(azurerm_subnet.subnet.*.id, 0)
    private_ip_address_allocation = "Static"
    private_ip_address            = "${var.node_address_prefixes[0]}.${format("%03d", count.index + 13)}"
    public_ip_address_id          = count.index == 3 ? azurerm_public_ip.public_ip_vm_04.id : null
    primary                       = true
  }
}

resource "azurerm_network_interface" "nic_02" {
  count               = var.total_node_count
  name                = "nic_02-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name
  ip_configuration {
    name                          = "ip_config"
    subnet_id                     = element(azurerm_subnet.subnet.*.id, 1)
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.2.${format("%03d", count.index + 13)}"
  }
}

### NSG Association

resource "azurerm_network_interface_security_group_association" "nsg" {
    count               = var.total_node_count
    network_interface_id      = element(azurerm_network_interface.nic_01.*.id, count.index)
    network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg_01"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name

}

resource "azurerm_network_security_rule" "rule_01" {
  name                        = "SSH"
  priority                    = 1000
  protocol                    = "Tcp"
  direction                   = "Inbound"
  access                      = "Allow"
  description                 = "SSH_Inbound"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  resource_group_name         = azurerm_resource_group.rgs.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "rule_02" {
  name                        = "RDP"
  priority                    = 1001
  protocol                    = "Tcp"
  direction                   = "Inbound"
  access                      = "Allow"
  description                 = "RDP_Inbound"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "3389"
  resource_group_name         = azurerm_resource_group.rgs.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "rule_03" {
  name                        = "API"
  priority                    = 500
  protocol                    = "*"
  direction                   = "Outbound"
  access                      = "Allow"
  description                 = "AzureRestAPIs"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "AzureCloud"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.rgs.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "rule_04" {
  name                        = "INT"
  priority                    = 501
  protocol                    = "*"
  direction                   = "Outbound"
  access                      = "Deny"
  description                 = "AzureRestAPIs"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "Internet"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.rgs.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}



resource "azurerm_lb" "ilb" {
  name                = "ilb_01"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name

  sku = "Standard"
  frontend_ip_configuration {
    name                          = "frontend_01"
    private_ip_address            = "192.168.1.10"
    private_ip_address_allocation = "Static"
    subnet_id                     = element(azurerm_subnet.subnet.*.id, 0)
  }
}

resource "azurerm_lb_backend_address_pool" "ilb" {
  name                = "pool_01"
  resource_group_name = azurerm_resource_group.rgs.name
  loadbalancer_id     = azurerm_lb.ilb.id
}

resource "azurerm_network_interface_backend_address_pool_association" "ilb" {
  count                   = 3
  network_interface_id    = element(azurerm_network_interface.nic_01.*.id, count.index)
  ip_configuration_name   = "ip_config"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ilb.id
}

resource "azurerm_lb_probe" "ilb" {
  name                = "probe_01"
  protocol            = "Tcp"
  port                = var.ilb_probe_port
  number_of_probes    = 3
  interval_in_seconds = 5
  resource_group_name = azurerm_resource_group.rgs.name
  loadbalancer_id     = azurerm_lb.ilb.id
}

resource "azurerm_lb_rule" "ilb" {
  resource_group_name            = azurerm_resource_group.rgs.name
  loadbalancer_id                = azurerm_lb.ilb.id
  name                           = "rule_01"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "frontend_01"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.ilb.id
  probe_id                       = azurerm_lb_probe.ilb.id
  enable_floating_ip             = true
  enable_tcp_reset               = false
}

###
resource "azurerm_lb" "plb" {
  name                = "plb_01"
  location            = azurerm_resource_group.rgs.location
  resource_group_name = azurerm_resource_group.rgs.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "frontend_01"
    public_ip_address_id = azurerm_public_ip.public_ip_plb.id

  }
}

resource "azurerm_lb_backend_address_pool" "plb" {
  name                = "pool_01"
  resource_group_name = azurerm_resource_group.rgs.name
  loadbalancer_id     = azurerm_lb.plb.id
}

resource "azurerm_network_interface_backend_address_pool_association" "plb" {
  count                   = 3
  network_interface_id    = element(azurerm_network_interface.nic_01.*.id, count.index)
  ip_configuration_name   = "ip_config"
  backend_address_pool_id = azurerm_lb_backend_address_pool.plb.id
}

resource "azurerm_lb_outbound_rule" "plb" {
  name                    = "outbound_rule_01"
  resource_group_name     = azurerm_resource_group.rgs.name
  loadbalancer_id         = azurerm_lb.plb.id
  protocol                = "All"
  enable_tcp_reset        = true
  backend_address_pool_id = azurerm_lb_backend_address_pool.plb.id
  frontend_ip_configuration {
    name = "frontend_01"
  }
  allocated_outbound_ports = 10000
  idle_timeout_in_minutes  = 4

}

resource "azurerm_managed_disk" "vms" {
  count                = 3
  name                 = "disk_${format("%02d", count.index + 1)}"
  location             = azurerm_resource_group.rgs.location
  resource_group_name  = azurerm_resource_group.rgs.name
  create_option        = "Empty"
  disk_size_gb         = 512
  storage_account_type = "Premium_LRS"

}
###
resource "azurerm_virtual_machine" "vms" {
  count                            = var.total_node_count
  name                             = "vm-gfs-${format("%02d", count.index + 1)}"
  location                         = azurerm_resource_group.rgs.location
  resource_group_name              = azurerm_resource_group.rgs.name
  network_interface_ids            = [element(azurerm_network_interface.nic_01.*.id, count.index), element(azurerm_network_interface.nic_02.*.id, count.index)]
  primary_network_interface_id     = element(azurerm_network_interface.nic_01.*.id, count.index)
  vm_size                          = "Standard_E4s_v4"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  availability_set_id = azurerm_availability_set.avs.id

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk_${format("%02d", count.index + 1)}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "vm-gfs-${format("%02d", count.index + 1)}"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    "environment" = "production"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "vms" {
  count              = var.cluster_node_count
  managed_disk_id    = element(azurerm_managed_disk.vms.*.id, count.index)
  virtual_machine_id = element(azurerm_virtual_machine.vms.*.id, count.index)
  lun                = 0
  caching            = "ReadWrite"
}
