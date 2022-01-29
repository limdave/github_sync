# Configure the Microsoft Azure Provider
# Create Vnet and Vnet peering
# Create VM on Azure Infra and ~~~      Naming Rule is "Resource Name-region-seperate-seq"
# 2022.01.03 limgongsik.

# Declare of the Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Declare of the Create Date and KST Time
locals {
    current_time = formatdate("YYYY.MM.DD HH:mmAA",timeadd(timestamp(),"9h"))
}

output "current_time" {
    value = local.current_time
}

# Create a resource group if it doesn't exist
# Must change rg-name and location 
resource "azurerm_resource_group" "ggResourcegroup" {
    #name     = "rg-eus-test11"
    #location = "eastus"
    name = var.resource_group
    location = var.location
    #tags = var.default_tags
    tags    = {
        envrionment = "test"
        datetime = "${local.current_time}"
        owner   = "gslim"
    }
}

# Create virtual networks
# Azure assigns private IP addresses to resources from the address range of the [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
resource "azurerm_virtual_network" "ggVnet01" {
    name                = "vnet-eus-hub01"
    address_space       = ["10.50.1.0/24"]
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    tags    = var.default_tags
}

resource "azurerm_virtual_network" "ggVnet02" {
    name                = "vnet-eus-spoke01"
    address_space       = ["10.50.2.0/24"]
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    tags    = var.default_tags
}

# Create subnet
resource "azurerm_subnet" "ggSubnet00" {
    name                 = "subnet-spoke01-00"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet02.name
    address_prefixes       = ["10.50.2.0/26"]
}

resource "azurerm_subnet" "ggSubnet01" {
    name                 = "subnet-spoke01-01"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet02.name
    address_prefixes       = ["10.50.2.64/26"]
}

/*
# Create Vnet peering
resource "azurerm_virtual_network_peering" "ggPeer-01" {
  name                      = "peer-hubtospoke1"
  resource_group_name       = azurerm_resource_group.ggResourcegroup.name
  virtual_network_name      = azurerm_virtual_network.ggVnet01.name
  remote_virtual_network_id = azurerm_virtual_network.ggVnet02.id
  #allow_gateway_transit     = true     #default=fault
  #use_remote_gateways       = true     #default=fault
}

resource "azurerm_virtual_network_peering" "ggPeer-02" {
  name                      = "peer-spoke1tohub"
  resource_group_name       = azurerm_resource_group.ggResourcegroup.name
  virtual_network_name      = azurerm_virtual_network.ggVnet02.name
  remote_virtual_network_id = azurerm_virtual_network.ggVnet01.id
}



# Create Network Security Group and rule
resource "azurerm_network_security_group" "ggNsg01" {
    name                = "nsg-vnet02subnet00"
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "RDP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags    = var.default_tags
}

# Create public IPs
resource "azurerm_public_ip" "ggPublicIP01" {
    name                         = "VM-AD-PublicIP01"
    location                     = azurerm_resource_group.ggResourcegroup.location
    resource_group_name          = azurerm_resource_group.ggResourcegroup.name
    #allocation_method            = "Dynamic"           #Dynamic 이면 IP주소 표시 안됨
    allocation_method            = "Static"

    tags    = var.default_tags
}


# Create network interface
resource "azurerm_network_interface" "ggNic01" {
    name                      = "VM-AD-NIC01"
    location                  = azurerm_resource_group.ggResourcegroup.location
    resource_group_name       = azurerm_resource_group.ggResourcegroup.name

    ip_configuration {
        name                          = "ggNic01Configuration"
        subnet_id                     = azurerm_subnet.ggSubnet00.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.ggPublicIP01.id
    }

    tags    = var.default_tags
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ggnic01asso" {
    network_interface_id      = azurerm_network_interface.ggNic01.id
    network_security_group_id = azurerm_network_security_group.ggNsg01.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.ggResourcegroup.name
    }
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "ggstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.ggResourcegroup.name
    location                    = azurerm_resource_group.ggResourcegroup.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags    = var.default_tags
}

resource "azurerm_windows_virtual_machine" "ggVM01" {
  name                = "VM-AD-Win2019"
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  location            = azurerm_resource_group.ggResourcegroup.location
  size                = "Standard_D2ds_v5"
  admin_username      = "ggadmin"
  #admin_password      = "Password#123"   #생성시 입력하도록...
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.ggNic01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags    = var.default_tags
}

### Display output information
output "VM-AD-ggPublicIP01" { 
    value = azurerm_public_ip.ggPublicIP01.ip_address
}

output "ggstorageaccount" { 
    value = azurerm_storage_account.ggstorageaccount.name
}

output "_Vnet_addreess" { 
    value = azurerm_virtual_network.ggVnet01.name
}




# Create public IPs
resource "azurerm_public_ip" "ggPublicIP10" {
    count = 3
    name                         = "VM-Linux-${count.index}pip"
    location                     = azurerm_resource_group.ggResourcegroup.location
    resource_group_name          = azurerm_resource_group.ggResourcegroup.name
    #allocation_method            = "Dynamic"           #Dynamic 이면 IP주소 표시 안됨
    allocation_method            = "Static"

    tags    = var.default_tags
}


# Create network interface
resource "azurerm_network_interface" "ggNic10" {
    count = 5
    name                      = "VM-Linux-NIC${count.index}"
    location                  = azurerm_resource_group.ggResourcegroup.location
    resource_group_name       = azurerm_resource_group.ggResourcegroup.name

    ip_configuration {
        name                          = "ggNic${count.index}Configuration"
        subnet_id                     = azurerm_subnet.ggSubnet01.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.ggPublicIP10[count.index].id
    }

    tags    = var.default_tags
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ggnic10asso" {
    count = 5
    network_interface_id      = azurerm_network_interface.ggNic10[count.index].id
    network_security_group_id = azurerm_network_security_group.ggNsg01.id
}

# Create linux virtual machine

resource "azurerm_linux_virtual_machine" "gglinuxVM10" {
    count = 5
    name                  = "VMlinux-${count.index}"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.ggResourcegroup.name
    network_interface_ids = [azurerm_network_interface.ggNic10[count.index].id]
    size                  = "Standard_D2s_v5"

    os_disk {
        name              = "ggOsDisk${count.index}"
        caching           = "ReadWrite"
        storage_account_type = "StandardSSD_LRS"
    }
    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.7"
        version   = "latest"
    }
    #source_image_reference {
    #    publisher = "Canonical"
    #    offer     = "UbuntuServer"
    #    sku       = "20.04-LTS"
    #    version   = "latest"
    #}
    
    computer_name  = "ggvm-${count.index}"
    admin_username = "ggadm"
    admin_password = var.admin_password
    disable_password_authentication = false
    #custom_data = filebase64("./apache.sh")

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.ggstorageaccount.primary_blob_endpoint
    }

    tags    = var.default_tags
}

### Display output Linux Vm information
output "VM-Linux-PublicIP10" { 
    value = azurerm_public_ip.ggPublicIP10.*.ip_address
}
*/
