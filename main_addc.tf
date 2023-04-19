# This is a creating the ms_sql database server for alwayson availability set
# Updated 2022.12.12
# Azure Virtual Machines의 SQL Server에서 가용성 그룹을 만들기 위한 필수 구성 요소
# https://learn.microsoft.com/ko-kr/azure/azure-sql/virtual-machines/windows/availability-group-manually-configure-prerequisites-tutorial-single-subnet?view=azuresql
# DC용 VM의 사설IP는 "정적"설정할 것

# Declare of the Create Date and KST Time
locals {
    current_time = formatdate("YYYY.MM.DD HH:mmAA",timeadd(timestamp(),"9h"))
    tags    = merge(var.default_tags, {datetime = "${local.current_time}",purpose = "mssql_AOAG"},)  #작성된 순서대로 표시되며, 동일 이름이면 나중 것으로 overwrite 된다
}

output "current_time" {
    value = local.current_time
}

#data "azurerm_client_config" "current" {}

# Create a resource group if it doesn't exist
resource "random_pet" "rg_name" {
  #prefix = var.resource_group_name
   prefix = var.prefix
}

# Must change rg-name and location / generate from random codename
resource "azurerm_resource_group" "ggResourcegroup" {
    name     = random_pet.rg_name.id
    #name     = var.resource_group_name
    location = var.location
    tags     = local.tags
}

# Create virtual networks
# Azure assigns private IP addresses to resources from the address range of the [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
resource "azurerm_virtual_network" "ggVnet01" {
    name                = "vnet-eus-internal"
    address_space       = ["10.20.1.0/24"]
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    tags    = local.tags
}

# Create subnet
resource "azurerm_subnet" "ggSubnet00" {
    name                 = "subnet-addomain-00"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes     = ["10.20.1.0/26"]
}

resource "azurerm_subnet" "ggSubnet01" {
    name                 = "subnet-alwayson-01"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes     = ["10.20.1.64/26"]
    #service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_subnet" "ggSubnet02" {
    name                 = "subnet-alwayson-02"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes     = ["10.20.1.128/26"]
}

# Create public IPs
resource "azurerm_public_ip" "ggPublicIP" {
    count = var.instances_num
    name                         = "VM-addc${count.index}-pip"
    location                     = azurerm_resource_group.ggResourcegroup.location
    resource_group_name          = azurerm_resource_group.ggResourcegroup.name
    #allocation_method            = "Dynamic"           #Dynamic 이면 IP주소 표시 안됨
    allocation_method            = "Static"

    tags    = local.tags
}

# Create network interface
resource "azurerm_network_interface" "ggNic" {
    count = var.instances_num
    name                      = "VM-addc${count.index}-nic"
    location                  = azurerm_resource_group.ggResourcegroup.location
    resource_group_name       = azurerm_resource_group.ggResourcegroup.name

    ip_configuration {
        name                          = "ggNic${count.index}Configuration"
        #for_each = toset( ["ggSubnet00", "ggSubnet01, "ggSubnet02"] )
        #subnet_id = each.key
        subnet_id                     = azurerm_subnet.ggSubnet00.id
        private_ip_address_allocation = "Dynamic"   #Dynamic
        #private_ip_address            = "10.20.1.4+[count.index]"  #When private_ip_address_allocation is set to Static the following fields can be configured:
        public_ip_address_id          = azurerm_public_ip.ggPublicIP[count.index].id    #공용IP가 불필요하면 comment처리할 것
    }

    tags    = local.tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ggNsg" {
    name                = "nsg-vnet01Subnet00"
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    security_rule {
        name                       = "ICMP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Icmp"
        source_port_range          = "*"
        destination_port_range     = "*"
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
        source_address_prefix      = "121.190.233.76"      #After create, assign a source ip address
        destination_address_prefix = "*"
    }
    tags = local.tags
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "ggnicasso" {
    count = var.instances_num
    network_interface_id      = azurerm_network_interface.ggNic[count.index].id
    network_security_group_id = azurerm_network_security_group.ggNsg.id
}

#data "azurerm_client_config" "current" {}

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

# Create a availablity set for VMs
resource "azurerm_availability_set" "avset" {
   name                         = "avset1ad"
   location                     = azurerm_resource_group.ggResourcegroup.location
   resource_group_name          = azurerm_resource_group.ggResourcegroup.name
   platform_fault_domain_count  = 2     #defaults is 3
   platform_update_domain_count = 3     #defaults is 5
   managed                      = true
   tags    = local.tags
}

# Create Windows virtual machine
resource "azurerm_windows_virtual_machine" "ggWinVM" {
    count = var.instances_num
    name                  = "VM-addc${count.index}"
    location              = azurerm_resource_group.ggResourcegroup.location
    resource_group_name   = azurerm_resource_group.ggResourcegroup.name
    availability_set_id   = azurerm_availability_set.avset.id
    network_interface_ids = [azurerm_network_interface.ggNic[count.index].id]
    size                  = "Standard_D2s_v5"
    license_type          = "Windows_Server"  #Possible values are None, Windows_Client and Windows_Server.(Optional) Specifies the type of on-premise license (also known as Azure Hybrid Use Benefit) which should be used for this Virtual Machine. 

    os_disk {
        name              = "ggOsDisk${count.index}-dc"
        caching           = "ReadWrite"                 #Possible values are None, ReadOnly and ReadWrite.
        storage_account_type = "Standard_LRS"           #HDD
        disk_size_gb      = 128
    }
    
    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2019-Datacenter"   #v1
        version   = "latest"
    }
    /*
    admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
    }
    */
    
    computer_name  = "vm-dc0${count.index}"
    admin_username = var.admin_usernameW
    admin_password = var.admin_password
    #admin_password = data.azurerm_key_vault_secret.kv_secret.value

    #boot_diagnostics {
    #    storage_account_uri = azurerm_storage_account.ggstorageaccount.primary_blob_endpoint
    #}
    timezone = "Korea Standard Time"
    #enable_automatic_updates    = "false"
    #patch_mode                  = "Manual"  #Possible values are Manual, AutomaticByOS and AutomaticByPlatform. Defaults to AutomaticByOS
    #provision_vm_agent          = "true"    #default
    tags    = local.tags
}



output "VM-Server-PublicIP" { 
    value = azurerm_public_ip.ggPublicIP[*].ip_address
}

# Manages automated shutdown schedules for Azure VMs that are not within an Azure DevTest Lab.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "ggWinVM" {
  count = var.instances_num 
  virtual_machine_id = azurerm_windows_virtual_machine.ggWinVM["${count.index}"].id
  location           = azurerm_resource_group.ggResourcegroup.location
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

    tags = var.default_tags
}
*/

/*
#Azure에서 동적 IP를 할당한 다음 고정 IP로 변환하도록 하려면 local-exec 프로비저너를 사용하여 리소스가 생성된 후 로컬 실행 파일을 호출할 수 있습니다. ==> 에러 발생
resource "null_resource" "example" {
   count = var.instances_num
   provisioner "local-exec" {

   command = <<EOT

      $Nic = Get-AzNetworkInterface -ResourceGroupName ${azurerm_resource_group.ggResourcegroup.name} -Name ${azurerm_network_interface.ggNic[count.index].name}
      $Nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
      Set-AzNetworkInterface -NetworkInterface $Nic
   EOT
   
   interpreter = ["PowerShell", "-Command"]
  }
  #depends_on = [azurerm_windows_virtual_machine.ggWinVM[count.index].name]
}
*/