# Reference : https://techcommunity.microsoft.com/t5/azure-database-for-mariadb-blog/using-terraform-to-create-private-endpoint-for-azure-database/ba-p/1279947
# the SKU Name for our Mysql, Mariadb, mariadb Server is follows the tier + family + cores pattern. For example: B_Gen4_1, GP_Gen5_8. / Family 약어 : Basic (B) ,GeneralPurpose (GP) ,MemoryOptimized (MO)
# Max storage  Possible values are 5120 MB(5GB) , 1048576 MB(1TB)  and 4194304 MB(4TB)
#============================================================
resource "azurerm_resource_group" "rg-example" {
  name     = "rg-krc-example"
  location = "Korea Central"

  tags = {
      owner = "gslim"
  }
}

#single server
resource "azurerm_mariadb_server" "mariasvr" {
  name                = "mariadb-svr1"
  location            = azurerm_resource_group.rg-example.location
  resource_group_name = azurerm_resource_group.rg-example.name

  sku_name = "GP_Gen5_2"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "ggdbadmin"
  administrator_login_password = "H@Sh1Corp3!"
  version                      = "10.2"      #The version of a mariadb server are 9.5, 9.6, 10, 10.0, and 11.13 , 12.8, 13.4
  ssl_enforcement_enabled      = true
  #ssl_minimal_tls_version_enforced = "TLS1_2"

  public_network_access_enabled = true

  tags = {
      owner = "gslim"
  }
}

resource "azurerm_mariadb_database" "mariadb10" {
  name                = "mariadb_exdb"      #contain only letters, numbers and underscores
  resource_group_name = azurerm_resource_group.rg-example.name
  server_name         = azurerm_mariadb_server.mariasvr.name
  charset             = "utf8mb4"             #utf8 또는 utf8mb4 / contain only lowercase letters and numbers
  collation           = "utf8mb4_general_ci"  #utf8_general_ci
}

resource "azurerm_mariadb_firewall_rule" "mariasvr-fw-rule" {
  name                = "mariadb_AccessRule"
  resource_group_name = azurerm_resource_group.rg-example.name
  server_name         = azurerm_mariadb_server.mariasvr.name
  start_ip_address    = "123.123.0.10"
  end_ip_address      = "123.123.0.20"
}

output "mariadb_server" {
  value = azurerm_mariadb_server.mariasvr.fqdn
}

#Private endpoints feature is supported only on General Purpose and Memory Optimized pricing tiers of Azure Database for mariadb Single server
resource "azurerm_virtual_network" "dbvnet" {
  name                = "db-network"
  address_space       = ["10.50.20.0/24"]
  location            = azurerm_resource_group.rg-example.location
  resource_group_name = azurerm_resource_group.rg-example.name
}

resource "azurerm_subnet" "dbsubnet" {
  name                 = "db-subnet0"
  resource_group_name  = azurerm_resource_group.rg-example.name
  virtual_network_name = azurerm_virtual_network.dbvnet.name
  address_prefixes     = ["10.50.20.0/26"]
  #service_endpoints    = ["Microsoft.Sql"]

  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_endpoint" "priv-endpoint" {
  name                = "dbprivate-endpoint"
  location            = azurerm_resource_group.rg-example.location
  resource_group_name = azurerm_resource_group.rg-example.name
  subnet_id           = azurerm_subnet.dbsubnet.id

  private_service_connection {
    name                           = "db-privatelinkconnection"
    private_connection_resource_id = azurerm_mariadb_server.mariasvr.id
    subresource_names              = [ "mariadbServer" ]
    is_manual_connection           = false
  }
}

output "mariadb_endpoint_IP_address" {
  value = azurerm_private_endpoint.priv-endpoint.network_interface
  #value = azurerm_private_endpoint.priv-endpoint.privateEndpointIpConfig
}

/*
# monitoring diagnostics
resource "azurerm_storage_account" "storeacc" {
  count                     = var.enable_logs_to_storage_account == true && var.log_analytics_workspace_name != null ? 1 : 0
  name                      = var.storage_account_name == null ? "stsqlauditlogs${element(concat(random_string.str.*.result, [""]), 0)}" : substr(var.storage_account_name, 0, 24)
  resource_group_name       = local.resource_group_name
  location                  = local.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  tags                      = merge({ "Name" = format("%s", "stsqlauditlogs") }, var.tags, )
}

resource "azurerm_monitor_diagnostic_setting" "extaudit" {
  count                      = var.log_analytics_workspace_name != null ? 1 : 0
  name                       = lower("extaudit-${var.mariadb_server_name}-diag")
  target_resource_id         = azurerm_mariadb_server.main.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.logws.0.id
  storage_account_id         = var.enable_logs_to_storage_account == true ? element(concat(azurerm_storage_account.storeacc.*.id, [""]), 0) : null

  dynamic "log" {
    for_each = var.extaudit_diag_logs
    content {
      category = log.value
      enabled  = true
      retention_policy {
        enabled = false
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }

  lifecycle {
    ignore_changes = [log, metric]
  }
}
*/