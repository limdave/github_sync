# This is create a Rocky linux VM and install http(apache) application script
# Updated 2022.07.16 limgong / 2023.11.04
# IaaS 3tier environment : for Linux Web Servers
# Terraform을 사용하여 Marketplace VM을 배포하려면 다음 작업을 수행해야 합니다.
#  1)azurerm_marketplace_agreement 사용하여 VM 제품 약관에 동의
#  2)plan azurerm_virtual_machine 공급자에서 블록 지정


# Declare of the Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"                 #2.99.0 --> latest v3.12.0
    }
  }
    # Use backed locally first. Commenting out this after configuring remote backend.
    #backend "local" {
    #  path = "./terraform.tfstate"
    #} 
}
provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the virtual network."
  default = "gslim-eus-rg"   
}

variable "location" {
  description = "The name of the location name in which to create the virtual network."
  default = "eastus"    #koreacentral, koreasouth
}

variable "default_tags" {
  description = "please define a tag name like date, role, environment and etc"
    type = map(string)
    default = {
        Envrionment = "test",
        datetime  = "2023.11.04 14:00",
        Creator   = "gslim"
    }
}

variable "system_sw" {
    type = list(string)
    default = [ "apache","tomcat","mariadb" ]
  
}

# Declare of the Create Date and KST Time
locals {
    current_time = formatdate("YYYY.MM.DD HH:mmAA",timeadd(timestamp(),"9h"))
    merge_tags  = merge(var.default_tags, {datetime = "${local.current_time}"})
}

output "current_time" {
    value = local.current_time
}


# Create a resource group if it doesn't exist
# Must change rg-name and location 
resource "azurerm_resource_group" "ggResourcegroup" {
    name     = var.resource_group_name
    location = var.location
    tags     = local.merge_tags
}

# Create virtual networks
# Azure assigns private IP addresses to resources from the address range of the [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
resource "azurerm_virtual_network" "ggVnet01" {
    name                = "vnet-eus-spoke01"
    address_space       = ["10.40.1.0/24"]
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    tags    = local.merge_tags
}

# Create subnet
resource "azurerm_subnet" "ggSubnet00" {
    name                 = "subnet-spoke01-00"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.40.1.0/26"]

}
resource "azurerm_subnet" "ggSubnet01" {
    name                 = "subnet-spoke01-01"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.40.1.64/26"]

}
resource "azurerm_subnet" "ggSubnet02" {
    name                 = "subnet-spoke01-02"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.40.1.128/26"]

}

# Create public IPs
resource "azurerm_public_ip" "ggPublicIP" {
    count = 1
    name                         = "VM-rocky${count.index}-pip"
    location                     = azurerm_resource_group.ggResourcegroup.location
    resource_group_name          = azurerm_resource_group.ggResourcegroup.name
    allocation_method            = "Static"

    tags    = local.merge_tags
}

# Create network interface
resource "azurerm_network_interface" "ggNic" {
    count = 1
    name                      = "VM-rocky-NIC${count.index}"
    location                  = azurerm_resource_group.ggResourcegroup.location
    resource_group_name       = azurerm_resource_group.ggResourcegroup.name

    ip_configuration {
        name                          = "ggNic${count.index}Configuration"
        #for_each = toset( ["ggSubnet00", "ggSubnet01, "ggSubnet02"] )
        #subnet_id = each.key
        subnet_id                     = azurerm_subnet.ggSubnet00.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.ggPublicIP[count.index].id    #공용IP가 불필요하면 comment처리할 것
    }

    tags    = local.merge_tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ggNsg" {
    name                = "nsg-vnet01Subnet00"
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
        name                       = "SSH"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "121.190.233.76"      #After create, assign a source ip address
        destination_address_prefix = "*"
    }
    tags = local.merge_tags
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
   location                     = azurerm_resource_group.ggResourcegroup.location
   resource_group_name          = azurerm_resource_group.ggResourcegroup.name
   platform_fault_domain_count  = 2     #defaults is 3
   platform_update_domain_count = 3     #defaults is 5
   managed                      = true
   tags    = local.merge_tags
}
*/

#https://portal.azure.com/#view/Microsoft_Azure_Marketplace/GalleryItemDetailsBladeNopdl/id/erockyenterprisesoftwarefoundationinc1653071250513.rockylinux-9/selectionMode~/false/resourceGroupId//resourceGroupLocation//dontDiscardJourney~/false/selectedMenuId/recentlyCreated/launchingContext~/%7B%22galleryItemId%22%3A%22erockyenterprisesoftwarefoundationinc1653071250513.rockylinux-9rockylinux-9%22%2C%22source%22%3A%5B%22GalleryFeaturedMenuItemPart%22%2C%22VirtualizedTileDetails%22%5D%2C%22telemetryId%22%3A%22ed9c88d4-5d0d-4dd6-bf36-2d6ffabb9fc3%22%7D
resource "azurerm_marketplace_agreement" "rockylinux" {
  publisher = "erockyenterprisesoftwarefoundationinc1653071250513"
  offer     = "rockylinux-9"
  plan      = "rockylinux-9"
}


# Create linux virtual machine
resource "azurerm_linux_virtual_machine" "gglinuxVM" {
    count = 1
    #for_each = toset(["apache","tomcat","mariadb"])
    name                  = "VM-rocky-0${count.index}"
    location              = azurerm_resource_group.ggResourcegroup.location
    resource_group_name   = azurerm_resource_group.ggResourcegroup.name
    #availability_set_id   = azurerm_availability_set.avset.id
    network_interface_ids = [azurerm_network_interface.ggNic[count.index].id]
    size                  = "Standard_D2s_v5"

    os_disk {
        name              = "ggOsDisk-${count.index}"
        caching           = "ReadWrite"
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb      = 32
    }

    plan{
        name = "rockylinux-9"
        product = "rockylinux-9"
        publisher = "erockyenterprisesoftwarefoundationinc1653071250513"
    }    
    source_image_reference {
        publisher = "erockyenterprisesoftwarefoundationinc1653071250513"
        offer     = "rockylinux-9"
        sku       = "rockylinux-9"     #9.1.20230215 on eastus
        version   = "latest"
    }



    /*
    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7_9-gen2"     #7_9-gen2 on eastus
        version   = "latest"
    }
    */
    /*
    admin_ssh_key {
        username   = var.admin_username
        public_key = file("~/.ssh/id_rsa.pub")
    }
    
    admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
    }
    */
    /*
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "20.04-LTS"
        version   = "latest"
    }
    */
    computer_name  = "ggvm-lix0${count.index}"
    admin_username = "ggadm"    #var.admin_username
    admin_password = "dlarhd!@#$1234"   #var.admin_password
    #admin_password = "${azurerm_key_vault_secret.ggsecret.value}"
    #admin_password = data.azurerm_key_vault_secret.kv_secret.value
    disable_password_authentication = false
    #for_each = toset(["apache","tomcat","mariadb"])
    #custom_data = base64encode(data.template_file.linux-vm-[each_value].rendered)
    custom_data = base64encode(data.template_file.linux-vm-apache.rendered)

    #boot_diagnostics {
    #    storage_account_uri = azurerm_storage_account.ggstorageaccount.primary_blob_endpoint
    #}

    tags    = local.merge_tags
}

# Template for bootstrapping
data "template_file" "linux-vm-apache" {
    template = file("./azure_http_data.sh")
}

### Display output Linux Vm information

output "VM-Linux-PublicIP" { 
    value = azurerm_public_ip.ggPublicIP[*].ip_address
}

# Manages automated shutdown schedules for Azure VMs that are not within an Azure DevTest Lab.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "gglinuxVM" {
  count = 1  
  virtual_machine_id = azurerm_linux_virtual_machine.gglinuxVM["${count.index}"].id
  location           = azurerm_resource_group.ggResourcegroup.location
  enabled            = true

  daily_recurrence_time = "1900"                    #The time each day when the schedule takes effect.HHmm
  timezone              = "Korea Standard Time"     #a full list of accepted time zone names.https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/

  notification_settings {
    enabled         = true      #Defaults to false
    email = "gongjags@outlook.kr"
  }
}

/*
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
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = local.merge_tags
}
*/
