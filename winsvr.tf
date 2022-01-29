# Declare of the Provider in main.tf
# This is create a Windows Server VM and install IIS
# Updated 2022.01.29 limgong
/*
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"   #latest is "2.94.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ggResourcegroup" {
  name     = "example-resources"
  location = "West Us"

  tags = {
    environment = "Windows Demo"
  }
}

# Create virtual networks
resource "azurerm_virtual_network" "example-vnet" {
  name                = "example-network"
  address_space       = ["10.0.90.0/24"]
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  tags = {
    environment = "Windows Demo"
  }
}

resource "azurerm_subnet" "example-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.ggResourcegroup.name
  virtual_network_name = azurerm_virtual_network.example-vnet.name
  address_prefixes     = ["10.0.90.0/26"]
}
*/

# Create public IPs
resource "azurerm_public_ip" "ggPublicIP02" {
    name                         = "VM-ggVM02-pip"
    location                     = azurerm_resource_group.ggResourcegroup.location
    resource_group_name          = azurerm_resource_group.ggResourcegroup.name
    #allocation_method            = "Dynamic"           #Dynamic 이면 IP주소 표시 안됨
    allocation_method            = "Static"

    tags = {
        environment = "Windows Demo"
    }
}

resource "azurerm_network_interface" "ggNic02" {
  name                = "VM-ggVM02-nic"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ggSubnet01.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ggPublicIP02.id
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ggNsg02" {
    name                = "nsg-vnet02Subnet01"
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    security_rule {
        name                       = "HTTP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
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
        source_address_prefix      = "*"      #After create, assign a source ip address
        destination_address_prefix = "*"
    }
    tags = {
        environment = "Windows Demo"
    }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ggNIC02asso" {
    network_interface_id      = azurerm_network_interface.ggNic02.id
    network_security_group_id = azurerm_network_security_group.ggNsg02.id
}


resource "azurerm_windows_virtual_machine" "ggVM02" {
  name                = "VM-ggVM02-win"
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  location            = azurerm_resource_group.ggResourcegroup.location
  size                = "Standard_D2ds_v5"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.ggNic02.id]

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

  #boot_diagnostics {
  #  storage_account_uri = "https://${var.diagnostics_storage_account_name}.blob.core.windows.net"
  #}
  tags    = var.default_tags
}

### Display output information
output "Windows2019_PublicIP" { 
    value = azurerm_public_ip.ggPublicIP02.ip_address
}

/*
resource "azurerm_virtual_machine_extension" "vm_extension_install_iis" {
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.ggVM02.id
  publisher                  = "Microsoft.Compute"      #"Microsoft.Azure.Extensions"
  type                       = "CustomScriptExtension"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
SETTINGS
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}
*/

