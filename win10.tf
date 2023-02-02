# This is create a CentOS linux VM and install http(apache) application script
# Updated 2022.07.16 limgong / 2023.02.02
# IaaS 3tier environment : for Linux Web Servers
# This is for JumpVM with 64GB OS disk and Win10

/*
# Declare of the Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"                 #2.99.0 --> latest v3.12.0
    }
  }
}
provider "azurerm" {
  features {}
}
*/

# Declare of the Create Date and KST Time
locals {
    current_time = formatdate("YYYY.MM.DD HH:mmAA",timeadd(timestamp(),"9h"))
}

output "current_time" {
    value = local.current_time
}

#data "azurerm_client_config" "current" {}

# Create a resource group if it doesn't exist
# Must change rg-name and location 
resource "azurerm_resource_group" "ggRG" {
    name     = var.resource_group_name
    location = var.location
    tags     = var.default_tags
}

# Create virtual networks
# Azure assigns private IP addresses to resources from the address range of the [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
resource "azurerm_virtual_network" "ggVnet01" {
    name                = "vnet-eus-jump01"
    address_space       = ["10.40.1.0/24"]
    location            = azurerm_resource_group.ggRG.location
    resource_group_name = azurerm_resource_group.ggRG.name

    tags    = var.default_tags
}

# Create subnet
resource "azurerm_subnet" "ggSubnet00" {
    name                 = "subnet-jump01-00"
    resource_group_name  = azurerm_resource_group.ggRG.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.40.1.0/26"]

}
resource "azurerm_subnet" "ggSubnet01" {
    name                 = "subnet-jump01-01"
    resource_group_name  = azurerm_resource_group.ggRG.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.40.1.64/26"]

}
resource "azurerm_subnet" "ggSubnet02" {
    name                 = "subnet-jump01-02"
    resource_group_name  = azurerm_resource_group.ggRG.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.40.1.128/26"]

}

# Create public IPs
resource "azurerm_public_ip" "ggPublicIP" {
    count = 1
    name                         = "VM-jump0${count.index}-pip"
    location                     = azurerm_resource_group.ggRG.location
    resource_group_name          = azurerm_resource_group.ggRG.name
    #allocation_method            = "Dynamic"           #Dynamic 이면 IP주소 표시 안됨
    allocation_method            = "Static"

    tags    = var.default_tags
}

# Create network interface
resource "azurerm_network_interface" "ggNic" {
    count = 1
    name                      = "VM-jump0${count.index}-nic"
    location                  = azurerm_resource_group.ggRG.location
    resource_group_name       = azurerm_resource_group.ggRG.name

    ip_configuration {
        name                          = "ggNic${count.index}Configuration"
        subnet_id                     = azurerm_subnet.ggSubnet00.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.ggPublicIP[count.index].id    #공용IP가 불필요하면 comment처리할 것
    }

    tags    = var.default_tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ggNsg" {
    name                = "nsg-vnet01Subnet00"
    location            = azurerm_resource_group.ggRG.location
    resource_group_name = azurerm_resource_group.ggRG.name

    security_rule {
        name                       = "RDP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "SSH"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"      #After create, assign a source ip address
        destination_address_prefix = "*"
    }
    tags = var.default_tags
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ggnicasso" {
    count = 1
    network_interface_id      = azurerm_network_interface.ggNic[count.index].id
    network_security_group_id = azurerm_network_security_group.ggNsg.id
}


/*
# Pull existing Key Vault from Azure
data "azurerm_key_vault" "kv" {
  name                = var.kv_name
  resource_group_name = var.kv_rgname
}

data "azurerm_key_vault_secret" "kv_secret" {
  name         = var.kv_secretname
  key_vault_id = data.azurerm_key_vault.kv.id
}


# Create (and display) an SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
*/
/*
# Create a availablity set for VMs
resource "azurerm_availability_set" "avset" {
   name                         = "avset1"
   location                     = azurerm_resource_group.ggRG.location
   resource_group_name          = azurerm_resource_group.ggRG.name
   platform_fault_domain_count  = 2     #defaults is 3
   platform_update_domain_count = 3     #defaults is 5
   managed                      = true
   tags    = var.default_tags
}
*/

# az vm image list -f "Windows-10" --all -o table
# Create Windows virtual machine
resource "azurerm_windows_virtual_machine" "windows_vm" {
    count = 1
    name                  = "VM-jump0${count.index}"
    location              = azurerm_resource_group.ggRG.location
    resource_group_name   = azurerm_resource_group.ggRG.name
    #availability_set_id   = azurerm_availability_set.avsetdb.id
    network_interface_ids = [azurerm_network_interface.ggNic[count.index].id]
    size                  = "Standard_D2s_v5"
    #zone                  = [count.index]
    #license_type          = "Windows_Server"  #Possible values are None, Windows_Client and Windows_Server.(Optional) Specifies the type of on-premise license (also known as Azure Hybrid Use Benefit) which should be used for this Virtual Machine. 

    os_disk {
        name              = "jpOsDisk${count.index}"
        caching           = "ReadWrite"                 #Possible values are None, ReadOnly and ReadWrite.
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb      = 127                 #Azure Marketplace 에서 이미지를 배포하여 리소스그룹에 새 VM(가상 머신)을 만들 때 기본 OS(운영 체제) 디스크는 일반적으로 127GiB입니다
    }
    
    source_image_reference {
        publisher = "MicrosoftWindowsDesktop"
        offer     = "windows-10"        #windows-10, windowsServer, SQL2019-WS2019, SQL2017-WS2016
        sku       = "win10-21h2-ent"       #win10-21h2-ent, enterprise, standard, SQLDEV, WEB  / -gen2
        version   = "latest"                #19044.2486.230107
    }
    /*
    admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
    }
    */
    
    computer_name  = "vm-jump0${count.index}"
    admin_username = var.admin_usernameW
    admin_password = var.admin_password
    #admin_password = data.azurerm_key_vault_secret.kv_secret.value

    #boot_diagnostics {
    #    storage_account_uri = azurerm_storage_account.ggstorageaccount.primary_blob_endpoint
    #}
    timezone                    = "Korea Standard Time"
    enable_automatic_updates    = "false"
    patch_mode                  = "Manual"  #Possible values are Manual, AutomaticByOS and AutomaticByPlatform. Defaults to AutomaticByOS
    provision_vm_agent          = "true"    #default
    tags    = var.default_tags
}

# Manages automated shutdown schedules for Azure VMs that are not within an Azure DevTest Lab.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "ggWinVM" {
  count = 1  
  virtual_machine_id = azurerm_windows_virtual_machine.windows_vm["${count.index}"].id
  location           = azurerm_resource_group.ggRG.location
  enabled            = true

  daily_recurrence_time = "1900"                    #The time each day when the schedule takes effect.HHmm
  timezone              = "Korea Standard Time"     #a full list of accepted time zone names.https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/

  notification_settings {
    enabled         = true      #Defaults to false
    email = "gslim@tdgl.co.kr"
  }
}

/*
# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.ggRG.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "ggstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.ggRG.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = var.default_tags
}
*/


### Display output Linux Vm information
output "VM-Jump-PublicIP" { 
    value = azurerm_public_ip.ggPublicIP[*].ip_address
}
output "vm_name0" {
  description = "Name of the VM"
  value       = azurerm_windows_virtual_machine.windows_vm[0].computer_name
}