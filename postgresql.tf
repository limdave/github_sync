# Reference : https://gmusumeci.medium.com/how-to-deploy-an-azure-database-for-postgresql-using-terraform-a35a0e0ded68
# the SKU Name for our PostgreSQL Server is follows the tier + family + cores pattern. For example: B_Gen4_1, GP_Gen5_8. / Family 약어 : Basic (B) ,GeneralPurpose (GP) ,MemoryOptimized (MO)
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
resource "azurerm_postgresql_server" "pgsvr" {
  name                = "pgsql-svr1"
  location            = azurerm_resource_group.rg-example.location
  resource_group_name = azurerm_resource_group.rg-example.name

  sku_name = "GP_Gen5_2"        #private link를 위해서는 GP이상 SKU를 사용해야 함

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "psqladmin"
  administrator_login_password = "H@Sh1Corp3!"
  version                      = "11"      #The version of a PostgreSQL server are 9.5, 9.6, 10, 10.0, and 11.13 , 12.8, 13.4
  ssl_enforcement_enabled      = true
  ssl_minimal_tls_version_enforced = "TLS1_2"

  public_network_access_enabled = true

  tags = {
      owner = "gslim"
  }
}

resource "azurerm_postgresql_database" "pgdb11" {
  name                = "pgexampledb"
  resource_group_name = azurerm_resource_group.rg-example.name
  server_name         = azurerm_postgresql_server.pgsvr.name
  charset             = "UTF8"                        #EUC_KR / LC_COLLATE='ko_KR.euckr'
  collation           = "English_United States.1252"  #OS제공 로케일 따라간다함 select * from pg_collation;
}

resource "azurerm_postgresql_firewall_rule" "pgsvr-fw-rule" {
  name                = "PostgreSQL_AccessRule"
  resource_group_name = azurerm_resource_group.rg-example.name
  server_name         = azurerm_postgresql_server.pgsvr.name
  start_ip_address    = "123.123.0.10"
  end_ip_address      = "123.123.0.20"
}

output "postgresql_server" {
  value = azurerm_postgresql_server.pgsvr.fqdn
}

#Private endpoints feature is supported only on General Purpose and Memory Optimized pricing tiers of Azure Database for PostgreSQL Single server
resource "azurerm_virtual_network" "dbvnet" {
  name                = "db-network"
  address_space       = ["10.50.10.0/24"]
  location            = azurerm_resource_group.rg-example.location
  resource_group_name = azurerm_resource_group.rg-example.name
}

resource "azurerm_subnet" "dbsubnet" {
  name                 = "db-subnet0"
  resource_group_name  = azurerm_resource_group.rg-example.name
  virtual_network_name = azurerm_virtual_network.dbvnet.name
  address_prefixes       = ["10.50.10.0/26"]

  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_endpoint" "priv-endpoint" {
  name                = "dbprivate-endpoint"
  location            = azurerm_resource_group.rg-example.location
  resource_group_name = azurerm_resource_group.rg-example.name
  subnet_id           = azurerm_subnet.dbsubnet.id

  private_service_connection {
    name                           = "db-privateserviceconnection"
    private_connection_resource_id = azurerm_postgresql_server.pgsvr.id
    subresource_names              = [ "postgresqlServer" ]
    is_manual_connection           = false
  }
}

output "postgresql_endpoint_IP_address" {
  value = azurerm_private_endpoint.priv-endpoint.private_dns_zone_configs
}