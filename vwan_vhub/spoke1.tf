locals {
    spoke1-location       = "eastus"
    spoke1-resource-group = "rg-spoke-vnet"
    prefix-spoke1         = "spoke1"
}

resource "azurerm_resource_group" "spoke1-vnet-rg" {
    name     = local.spoke1-resource-group
    location = local.spoke1-location

    tags = var.tags
}

resource "azurerm_virtual_network" "spoke1-vnet" {
    name                = "spoke1-vnet"
    location            = azurerm_resource_group.spoke1-vnet-rg.location
    resource_group_name = azurerm_resource_group.spoke1-vnet-rg.name
    address_space       = ["10.80.0.0/16"]

    tags = {
    environment = local.prefix-spoke1
    }
}

resource "azurerm_subnet" "spoke1-mgmt" {
    name                 = "mgmt"
    resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
    virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
    address_prefixes     = ["10.80.0.0/24"]
}

resource "azurerm_subnet" "spoke1-workload" {
    name                 = "workload"
    resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
    virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
    address_prefixes     = ["10.80.1.0/24"]
}

/*
resource "azurerm_virtual_network_peering" "spoke1-hub-peer" {
    name                      = "spoke1-hub-peer"
    resource_group_name       = azurerm_resource_group.spoke1-vnet-rg.name
    virtual_network_name      = azurerm_virtual_network.spoke1-vnet.name
    remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

    allow_virtual_network_access = true
    allow_forwarded_traffic = true
    allow_gateway_transit   = false
    use_remote_gateways     = true
    depends_on = [azurerm_virtual_network.spoke1-vnet, azurerm_virtual_network.hub-vnet , azurerm_virtual_network_gateway.hub-vnet-gateway]
}
*/

resource "azurerm_network_interface" "spoke1-nic" {
    name                 = "${local.prefix-spoke1}-nic"
    location             = azurerm_resource_group.spoke1-vnet-rg.location
    resource_group_name  = azurerm_resource_group.spoke1-vnet-rg.name
    enable_ip_forwarding = true

    ip_configuration {
    name                          = local.prefix-spoke1
    subnet_id                     = azurerm_subnet.spoke1-mgmt.id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id : 공용IP가 필요하면 추가, 공용IP를 생성하면 NSG도 반드시 생성
    }
}

/*
#RDP Access Rules for Lab
#Get Client IP Address for NSG
data "http" "clientip" {
  url = "https://ipv4.icanhazip.com/"
}
#Lab NSG
resource "azurerm_network_security_group" "spoke1-nsg" {
  name                = "spoke1-nsg"
  location            = var.loc1
  resource_group_name = azurerm_resource_group.rg2.name

  security_rule {
    name                       = "RDP-In"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${chomp(data.http.clientip.body)}/32"
    destination_address_prefix = "*"
  }
  tags = var.tags
  }
}
#NSG Association to all Lab Subnets
resource "azurerm_subnet_network_security_group_association" "vnet1-snet1" {
  subnet_id                 = azurerm_subnet.spoke1-mgmt.id
  network_security_group_id = azurerm_network_security_group.spoke1-nsg.id
}

*/

resource "azurerm_windows_virtual_machine" "spoke1-vm" {
  name                = "${local.prefix-spoke1}-vm"
  location              = azurerm_resource_group.spoke1-vnet-rg.location
  resource_group_name   = azurerm_resource_group.spoke1-vnet-rg.name
  network_interface_ids = [azurerm_network_interface.spoke1-nic.id]
  size                  = var.vmsize

  computer_name  = "${local.prefix-spoke1}-vm"
  admin_username      = var.username
  admin_password      = var.password

  os_disk {
    name              = "myosdisk1"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags    = var.tags
}

/*
resource "azurerm_virtual_network_peering" "hub-spoke1-peer" {
    name                      = "hub-spoke1-peer"
    resource_group_name       = azurerm_resource_group.hub-vnet-rg.name
    virtual_network_name      = azurerm_virtual_network.hub-vnet.name
    remote_virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
    allow_virtual_network_access = true
    allow_forwarded_traffic   = true
    allow_gateway_transit     = true
    use_remote_gateways       = false
    depends_on = [azurerm_virtual_network.spoke1-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}
*/