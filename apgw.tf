#Reference : https://faun.pub/build-an-azure-application-gateway-with-terraform-8264fbd5fa42
#Updated at 2022.02.05
#appgw with key vault
############### 진행중  ########################

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.254.0.0/16"]
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.0.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.254.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "example-pip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"
}

# -
# - Application Gateway (L7 load balancer)
# -
resource "azurerm_application_gateway" "agw" {
  depends_on          = [azurerm_key_vault_certificate.mysite1, time_sleep.wait_60_seconds]
  name                = "${local.prefix}-hub-agw1"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  enable_http2        = true
  zones               = local.zones
  tags                = data.azurerm_resource_group.rg.tags

  sku {
    name = local.sku_name
    tier = local.sku_tier
  }

  autoscale_configuration {
    min_capacity = local.capacity.min
    max_capacity = local.capacity.max
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agw.id]
  }

  gateway_ip_configuration {
    name      = "${local.prefix}-hub-agw1-ip-configuration"
    subnet_id = local.subnet_id
  }

  frontend_ip_configuration {
    name                 = "${local.frontend_ip_configuration_name}-public"
    public_ip_address_id = azurerm_public_ip.agw.id
  }

  frontend_port {
    name = "${local.frontend_port_name}-80"
    port = 80
  }

  frontend_port {
    name = "${local.frontend_port_name}-443"
    port = 443
  }

  backend_address_pool {
    name  = local.backend_address_pool.name
    fqdns = local.backend_address_pool.fqdns
  }

  ssl_certificate {
    name                = azurerm_key_vault_certificate.mysite1.name
    key_vault_secret_id = azurerm_key_vault_certificate.mysite1.secret_id
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    host_name             = local.backend_address_pool.fqdns[0]
    request_timeout       = 1
  }

  http_listener {
    name                           = "${local.listener_name}-http"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}-public"
    frontend_port_name             = "${local.frontend_port_name}-80"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "${local.listener_name}-https"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}-public"
    frontend_port_name             = "${local.frontend_port_name}-443"
    protocol                       = "Https"
    ssl_certificate_name           = azurerm_key_vault_certificate.mysite1.name
  }

  request_routing_rule {
    name                       = "${local.request_routing_rule_name}-https"
    rule_type                  = "Basic"
    http_listener_name         = "${local.listener_name}-https"
    backend_address_pool_name  = local.backend_address_pool.name
    backend_http_settings_name = local.http_setting_name
  }

  redirect_configuration {
    name                 = local.redirect_configuration_name
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
    target_listener_name = "${local.listener_name}-https"
  }

  request_routing_rule {
    name                        = "${local.request_routing_rule_name}-http"
    rule_type                   = "Basic"
    http_listener_name          = "${local.listener_name}-http"
    redirect_configuration_name = local.redirect_configuration_name
  }

  // Ignore most changes as they will be managed manually
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      request_routing_rule,
      url_path_map,
      ssl_certificate,
      redirect_configuration,
      autoscale_configuration
    ]
  }
}