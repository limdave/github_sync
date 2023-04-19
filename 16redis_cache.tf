#This example provisions a Standard Redis Cache.


# NOTE: the Name used for Redis needs to be globally unique
resource "azurerm_redis_cache" "stdredis" {
  name                = "${var.prefix}std-cache"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  capacity            = 2           #Valid values for a SKU family of C (Basic/Standard) are 0, 1, 2, 3, 4, 5, 6, and for P (Premium) family are 1, 2, 3, 4.
  family              = "C"         #Valid values are C (for Basic/Standard SKU family) and P (for Premium)
  sku_name            = "Standard"  #Possible values are Basic, Standard and Premium.
  enable_non_ssl_port = false       #Enable the non-SSL port (6379) - disabled by default.
  minimum_tls_version = "1.2"
  #private_static_ip_address    = string
  #subnet_id   = string 
  #public_network_access_enabled = false    #default to true:means this resource could be accessed by both public and private endpoint. 

  redis_configuration {
  }
  tags = var.default_tags
}

resource "azurerm_redis_firewall_rule" "redisfw" {
  name                = "someIPrange"
  redis_cache_name    = azurerm_redis_cache.stdredis.name
  resource_group_name = azurerm_resource_group.aks_rg.name
  start_ip            = "58.151.57.2"
  end_ip              = "58.151.57.4"
}


/* this is a basic sku
# NOTE: the Name used for Redis needs to be globally unique
resource "azurerm_redis_cache" "example" {
  name                = "${var.prefix}-redis"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  enable_non_ssl_port = false
}
*/
/* this is a premium sku and backup
resource "azurerm_storage_account" "example" {
  name                     = "${var.prefix}sa"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

# NOTE: the Name used for Redis needs to be globally unique
resource "azurerm_redis_cache" "example" {
  name                = "${var.prefix}-cache"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  capacity            = 3
  family              = "P"
  sku_name            = "Premium"
  enable_non_ssl_port = false

  redis_configuration {
    rdb_backup_enabled            = true
    rdb_backup_frequency          = 60
    rdb_backup_max_snapshot_count = 1
    rdb_storage_connection_string = azurerm_storage_account.example.primary_blob_connection_string
  }
}
*/