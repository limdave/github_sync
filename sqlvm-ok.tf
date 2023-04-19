# Terraform을 사용하여 SQL Server VM 및 SQL Server IaaS 에이전트 확장을 구성하는 방법을 보여줍니다.
# Terraform은 azurerm_mssql_virtual_machine 리소스 블록을 사용하여 이 관리를 지원합니다 .
# https://faun.pub/using-terraform-to-configure-sql-server-on-azure-vm-7cdba2c1a3b3
# High Availability SQL Always-On Cluster : https://github.com/canada-ca-terraform-modules/terraform-azurerm-sql-server-cluster
# Disk의 LUN이슈해결안 : https://stackoverflow.com/questions/75325663/error-with-storage-when-using-new-disk-type-in-terraform-sql-server-virtual-mach
# 2023.03.07 정상적으로 SQL VM이 생성되는 코드임.
/*
This template creates the following resources:

  1 storage account for the diagnostics
  1 internal load balancer (in single subnet)
  1 availability set for SQL Server and Witness virtual machines , SQL Server 2016 이상 Enterprise Edition을 실행하는 Azure의 하나 이상의 도메인 조인 VM.
  3 virtual machines in a Windows Server Cluster
    - 2 SQL Server edition replicas with an availability group
    - 1 virtual machine is a File Share Witness for the Cluster  or cloud witness with storage account
  4. 성능가이드라인 모범사례(https://learn.microsoft.com/ko-kr/azure/azure-sql/virtual-machines/windows/performance-guidelines-best-practices-checklist?view=azuresql)
E4ds_v5 이상과 같이 vCPU가 4개 이상인 VM 크기를 사용합니다.
SQL Server 워크로드의 최고 성능을 위해 메모리가 최적화된 가상 머신 크기를 사용합니다.
데이터, 로그 및 tempdb 파일을 별개의 드라이브에 배치합니다.(디스크에 대한 캐시 설정을 변경하는 경우 데이터 손상 방지를 위해 다른 관련 서비스와 함께 SQL Server 서비스를 중지해야 합니다.)
대부분의 SQL Server 워크로드의 경우 로컬 임시 SSD(기본값 D:\) 드라이브에 tempdb를 배치합니다. FCI의 경우 공유 스토리지에 tempdb를 배치합니다.
*/


/*
# Declare of the Create Date and KST Time
locals {
    current_time = formatdate("YYYY.MM.DD HH:mmAA",timeadd(timestamp(),"9h"))
    tags    = merge(var.default_tags, {datetime = "${local.current_time}",purpose = "mssql_AOAG"},)  #작성된 순서대로 표시되며, 동일 이름이면 나중 것으로 overwrite 된다
}
*/
resource "azurerm_public_ip" "vm_pip" {
  count = var.instances_num
  name                = "VM-sql${count.index}-PIP"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  allocation_method   = "Static"
  tags    = local.tags
}


resource "azurerm_network_interface" "vm_nic" {
  count = var.instances_num
  name                = "VM-sql${count.index}-NIC"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name

  ip_configuration {
    name                          = "VM-sql${count.index}-IP"
    subnet_id                     = azurerm_subnet.ggSubnet01.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
  }

  tags    = local.tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "vm_nsg" {
    name                = "nsg-vnet01Subnet01"
    location            = azurerm_resource_group.ggResourcegroup.location
    resource_group_name = azurerm_resource_group.ggResourcegroup.name

    security_rule {
        name                       = "MSSQL"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "1433"
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
    tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "vm_nic_sg" {
  count = var.instances_num
  network_interface_id      = azurerm_network_interface.vm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Create a availablity set for VMs
resource "azurerm_availability_set" "avsetdb" {
   name                         = "avset2db"
   location                     = azurerm_resource_group.ggResourcegroup.location
   resource_group_name          = azurerm_resource_group.ggResourcegroup.name
   platform_fault_domain_count  = 3     #defaults is 3
   platform_update_domain_count = 5     #defaults is 5
   managed                      = true
   tags    = local.tags
}

/*
resource "azurerm_virtual_machine" "windows_vm" {
  name                             = var.vm_name
  vm_size                          = var.vm_size
  location                         = var.location
  resource_group_name              = var.resource_group_name
  availability_set_id              = var.availability_set_id
  delete_os_disk_on_termination    = var.vm_os_disk_delete_flag
  delete_data_disks_on_termination = var.vm_data_disk_delete_flag

  tags    = local.tags

  network_interface_ids = [azurerm_network_interface.vm_nic.id, ]

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2019-WS2019"    #SQL2019-WS2019, SQL2017-WS2016
    sku       = "ENTERPRISE"          #enterprise, standard, SQLDEV, WEB  / -gen2
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  storage_os_disk {
    name              = "${var.vm_name}-OS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = 128
  }

  storage_data_disk {
    name              = "${var.vm_name}-DATA"
    caching           = "ReadOnly"
    create_option     = "Empty"
    disk_size_gb      = 256
    lun               = 0
    managed_disk_type = "Premium_LRS"
  }

  storage_data_disk {
    name              = "${var.vm_name}-LOG"
    caching           = "ReadOnly"
    create_option     = "Empty"
    disk_size_gb      = 128
    lun               = 1
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    admin_password = var.admin_password
    admin_username = var.admin_username
    computer_name  = var.computer_name
  }

  os_profile_windows_config {
    timezone           = "KST"    #UTC
    provision_vm_agent = true
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = var.storage_uri
  }

}
*/
#//az vm image list --location eastus  --publisher MicrosoftSQLServer  --all --output table
# Create Windows virtual machine
resource "azurerm_windows_virtual_machine" "windows_vm" {
    count = var.instances_num
    name                  = "VM-sqldb0${count.index}"
    location              = azurerm_resource_group.ggResourcegroup.location
    resource_group_name   = azurerm_resource_group.ggResourcegroup.name
    availability_set_id   = azurerm_availability_set.avsetdb.id
    network_interface_ids = [azurerm_network_interface.vm_nic[count.index].id]
    size                  = "Standard_D2ds_v5"
    #zone                  = [count.index]
    license_type          = "Windows_Server"  #Possible values are None, Windows_Client and Windows_Server.(Optional) Specifies the type of on-premise license (also known as Azure Hybrid Use Benefit) which should be used for this Virtual Machine. 

    os_disk {
        name              = "dbOsDisk${count.index}"
        caching           = "ReadWrite"                 #Possible values are None, ReadOnly and ReadWrite.
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb      = 127
    }
    
    source_image_reference {
        publisher = "MicrosoftSQLServer"
        offer     = "SQL2019-WS2019"        #SQL2019-WS2019, SQL2017-WS2016
        sku       = "SQLDEV"       #enterprise, standard, SQLDEV, WEB  / -gen2
        version   = "latest"
    }
    /*
    admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
    }
    */
    
    computer_name  = "vm-sqldb${count.index}"
    admin_username = var.admin_usernameW
    admin_password = var.admin_password
    #admin_password = data.azurerm_key_vault_secret.kv_secret.value

    #boot_diagnostics {
    #    storage_account_uri = azurerm_storage_account.ggstorageaccount.primary_blob_endpoint
    #}
    timezone                    = "Korea Standard Time"
    enable_automatic_updates    = false
    patch_mode                  = "Manual"  #Possible values are Manual, AutomaticByOS and AutomaticByPlatform. Defaults to AutomaticByOS
    provision_vm_agent          = true    #default
    tags    = local.tags
}


# add a data disk - we were going to iterate through a collection, but this is easier for now
resource "azurerm_managed_disk" "datadisk" {
    count = var.instances_num
    name                    = "${azurerm_windows_virtual_machine.windows_vm[count.index].name}-data-disk01" 
    location                = azurerm_resource_group.ggResourcegroup.location
    resource_group_name     = azurerm_resource_group.ggResourcegroup.name
    storage_account_type    = "Premium_LRS"   #Possible values are Standard_LRS, StandardSSD_ZRS, Premium_LRS, PremiumV2_LRS, Premium_ZRS, StandardSSD_LRS or UltraSSD_LRS.
    #zones                   = [var.instancezone]
    create_option           = "Empty"   #is FromImage or Import. Empty
    disk_size_gb            = 32
    tags                    = local.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadisk_attach" {
    count = var.instances_num
    managed_disk_id    = azurerm_managed_disk.datadisk[count.index].id
    virtual_machine_id = azurerm_windows_virtual_machine.windows_vm[count.index].id
    lun                = count.index
    caching            = "ReadOnly" #데이터 파일 디스크에 대해 호스트 캐싱을 읽기 전용으로 설정합니다. Possible values include None, ReadOnly and ReadWrite.
    #depends_on         = [azurerm_windows_virtual_machine.vm]
}

# add a log disk - we were going to iterate through a collection, but this is easier for now
resource "azurerm_managed_disk" "logdisk" {
    count = var.instances_num
    name                    = "${azurerm_windows_virtual_machine.windows_vm[count.index].name}-log-disk01" 
    location                = azurerm_resource_group.ggResourcegroup.location
    resource_group_name     = azurerm_resource_group.ggResourcegroup.name
    storage_account_type    = "Premium_LRS"
    #zones                    = [var.instancezone]
    create_option           = "Empty"     #is FromImage or Import. Empty
    disk_size_gb            = 64
    tags                    = local.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "logdisk_attach" {
    count = var.instances_num
    managed_disk_id    = azurerm_managed_disk.logdisk[count.index].id
    virtual_machine_id = azurerm_windows_virtual_machine.windows_vm[count.index].id
    lun                = count.index + 1
    caching            = "None"   #로그 파일 디스크에 대해 호스트 캐싱을 없음으로 설정합니다
}

# SQL Settings
resource "azurerm_mssql_virtual_machine" "sqlvmmanagement" {
  count = var.instances_num
  virtual_machine_id               = azurerm_windows_virtual_machine.windows_vm[count.index].id

  sql_license_type                 = "PAYG"   #Possible values are AHUB (Azure Hybrid Benefit), DR (Disaster Recovery), and PAYG (Pay-As-You-Go). 
  sql_connectivity_port            = 1433
  sql_connectivity_type            = "PRIVATE"
  r_services_enabled               = false
  sql_connectivity_update_username = var.sql_connectivity_update_username #(Optional) The SQL Server sysadmin login to create.
  sql_connectivity_update_password = var.sql_connectivity_update_password #(Optional) The SQL Server sysadmin login password.
  #sql_connectivity_update_password = data.azurerm_key_vault_secret.sqladminpwd.value
  sql_instance {
    adhoc_workloads_optimization_enabled = false   #Defaults to false
    collation = "SQL_Latin1_General_CP1_CI_AS"      #default
  }

  storage_configuration {
    disk_type             = "NEW"  # (Required) The type of disk configuration to apply to the SQL Server. Valid values include NEW, EXTEND, or ADD.
    storage_workload_type = "OLTP" # (Required) The type of storage workload. Valid values include GENERAL, OLTP, or DW.

    # The storage_settings block supports the following:
    data_settings {
      default_file_path = "F:\\SqlData" # (Required) The SQL Server default path
      #luns              = [0]
      luns = [azurerm_virtual_machine_data_disk_attachment.datadisk_attach[count.index].lun]
      #depends_on = [
      #    azurerm_virtual_machine_data_disk_attachment.datadisk_attach[count.index]
      #]
    }
    log_settings {
      default_file_path = "G:\\SqlLogs" # (Required) The SQL Server default path
      #luns              = [1]
      luns              = [azurerm_virtual_machine_data_disk_attachment.logdisk_attach[count.index].lun]    #1, azurerm_virtual_machine_data_disk_attachment.logdisk_attach[count.index].lun] # (Required) A list of Logical Unit Numbers for the disks.
      #depends_on = [
      #    azurerm_virtual_machine_data_disk_attachment.logdisk_attach[count.index]
      #]
    }
    temp_db_settings {
      default_file_path  = "D:\\SqlTemp"
      luns               = []
    }
    system_db_on_data_disk_enabled = false  # (Optional) Specifies whether to set system databases (except tempDb) location to newly created data storage. default=false
  }

  auto_patching {
    day_of_week                            = "Sunday"
    maintenance_window_duration_in_minutes = 60
    maintenance_window_starting_hour       = 2
  }

  auto_backup {
    encryption_enabled          = false
    #manual_schedule  = Automated
    retention_period_in_days    = 30
    storage_blob_endpoint       = azurerm_storage_account.sqlbackup.primary_blob_endpoint
    storage_account_access_key  = azurerm_storage_account.sqlbackup.primary_access_key
    system_databases_backup_enabled = false
    
    manual_schedule {
      full_backup_frequency           = "Weekly"   #Valid values include Daily or Weekly.
      full_backup_start_hour          = 4
      full_backup_window_in_hours     = 4
      log_backup_frequency_in_minutes = 60
      #days_of_week                    = [Saturday]
    }
  }
  depends_on = [
        azurerm_virtual_machine_data_disk_attachment.datadisk_attach,
        azurerm_virtual_machine_data_disk_attachment.logdisk_attach,
  ]
}


# Manages automated shutdown schedules for Azure VMs that are not within an Azure DevTest Lab.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "ggVM" {
  count = var.instances_num
  virtual_machine_id = azurerm_windows_virtual_machine.windows_vm["${count.index}"].id
  location           = azurerm_resource_group.ggResourcegroup.location
  enabled            = true

  daily_recurrence_time = "1900"                    #The time each day when the schedule takes effect.HHmm
  timezone              = "Korea Standard Time"     #a full list of accepted time zone names.https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/

  notification_settings {
    enabled         = true      #Defaults to false
    email           = "gslim@tdgl.co.kr"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomid" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.ggResourcegroup.name
    }
    byte_length = 2
}

#Create the storage account that will hold the SQL Backups
resource "azurerm_storage_account" "sqlbackup" {
  name                     = "sta2backup${random_id.randomid.hex}"
  location                 = azurerm_resource_group.ggResourcegroup.location
  resource_group_name      = azurerm_resource_group.ggResourcegroup.name
  account_kind             = "StorageV2"  #Valid options are BlobStorage, BlockBlobStorage, FileStorage, Storage and StorageV2(default)
  account_tier             = "Standard"   #Valid options are Standard and Premium
  account_replication_type = "LRS"
  access_tier              = "Hot"
  enable_https_traffic_only = true
  tags                     = local.tags
}

/*
# ----------- DOMAIN JOIN --------------------------------
// Waits for up to 1 hour for the Domain to become available. Will return an error 1 if unsuccessful preventing the member attempting to join.
resource "azurerm_virtual_machine_extension" "wait-for-domain-to-provision" {
  name                 = "TestConnectionDomain"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  settings             = <<SETTINGS
  {
    "commandToExecute": "powershell.exe -Command \"while (!(Test-Connection -ComputerName ${var.active_directory_domain_name} -Count 1 -Quiet) -and ($retryCount++ -le 360)) { Start-Sleep 10 } \""
  }
SETTINGS
}
resource "azurerm_virtual_machine_extension" "join-domain" {
  name                 = azurerm_windows_virtual_machine.vm.name
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  settings             = <<SETTINGS
    {
        "Name": "${var.active_directory_domain_name}",
        "OUPath": "",
        "User": "${var.active_directory_username}@${var.active_directory_domain_name}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS
  protected_settings   = <<SETTINGS
    {
        "Password": "${var.active_directory_password}"
    }
SETTINGS
  depends_on           = [azurerm_virtual_machine_extension.wait-for-domain-to-provision]
}
*/

#Microsoft.SqlVirtualMachine/sqlVirtualMachines 리소스를 만들려면 템플릿에 다음 Terraform을 추가합니다.
/*
resource "azapi_resource" "symbolicname" {
  type = "Microsoft.SqlVirtualMachine/sqlVirtualMachines@2022-07-01-preview"
  name = "string"
  location = "string"
  parent_id = "string"
  tags = {
    tagName1 = "tagValue1"
    tagName2 = "tagValue2"
  }
  identity {
    type =  "SystemAssigned"
  }
  body = jsonencode({
    properties = {
      assessmentSettings = {
        enable = bool
        runImmediately = bool
        schedule = {
          dayOfWeek = "string"
          enable = bool
          monthlyOccurrence = int
          startTime = "string"
          weeklyInterval = int
        }
      }
      autoBackupSettings = {
        backupScheduleType = "string"
        backupSystemDbs = bool
        daysOfWeek = [
          "string"
        ]
        enable = bool
        enableEncryption = bool
        fullBackupFrequency = "string"
        fullBackupStartTime = int
        fullBackupWindowHours = int
        logBackupFrequency = int
        password = "string"
        retentionPeriod = int
        storageAccessKey = "string"
        storageAccountUrl = "string"
        storageContainerName = "string"
      }
      autoPatchingSettings = {
        dayOfWeek = "string"
        enable = bool
        maintenanceWindowDuration = int
        maintenanceWindowStartingHour = int
      }
      enableAutomaticUpgrade = bool
      keyVaultCredentialSettings = {
        azureKeyVaultUrl = "string"
        credentialName = "string"
        enable = bool
        servicePrincipalName = "string"
        servicePrincipalSecret = "string"
      }
      leastPrivilegeMode = "Enabled"
      serverConfigurationsManagementSettings = {
        additionalFeaturesServerConfigurations = {
          isRServicesEnabled = bool
        }
        sqlConnectivityUpdateSettings = {
          connectivityType = "string"
          port = int
          sqlAuthUpdatePassword = "string"
          sqlAuthUpdateUserName = "string"
        }
        sqlInstanceSettings = {
          collation = "string"
          isIfiEnabled = bool
          isLpimEnabled = bool
          isOptimizeForAdHocWorkloadsEnabled = bool
          maxDop = int
          maxServerMemoryMB = int
          minServerMemoryMB = int
        }
        sqlStorageUpdateSettings = {
          diskConfigurationType = "string"
          diskCount = int
          startingDeviceId = int
        }
        sqlWorkloadTypeUpdateSettings = {
          sqlWorkloadType = "string"
        }
      }
      sqlImageOffer = "string"
      sqlImageSku = "string"
      sqlManagement = "string"
      sqlServerLicenseType = "string"
      sqlVirtualMachineGroupResourceId = "string"
      storageConfigurationSettings = {
        diskConfigurationType = "string"
        sqlDataSettings = {
          defaultFilePath = "string"
          luns = [
            int
          ]
        }
        sqlLogSettings = {
          defaultFilePath = "string"
          luns = [
            int
          ]
        }
        sqlSystemDbOnDataDisk = bool
        sqlTempDbSettings = {
          dataFileCount = int
          dataFileSize = int
          dataGrowth = int
          defaultFilePath = "string"
          logFileSize = int
          logGrowth = int
          luns = [
            int
          ]
          persistFolder = bool
          persistFolderPath = "string"
        }
        storageWorkloadType = "string"
      }
      virtualMachineResourceId = "string"
      wsfcDomainCredentials = {
        clusterBootstrapAccountPassword = "string"
        clusterOperatorAccountPassword = "string"
        sqlServiceAccountPassword = "string"
      }
      wsfcStaticIp = "string"
    }
  })
}
*/

