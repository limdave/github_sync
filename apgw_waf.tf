#Reference : https://faun.pub/build-an-azure-application-gateway-with-terraform-8264fbd5fa42
#            https://github.com/kumarvna/terraform-azurerm-application-gateway
#Updated at 2022.02.05
#appgw with key vault 
#(2022.08.16)https 설정을 위해서는 *.pfx 파일이 필요하고, 해당 파일이 Keyvalut에 등록되어 있어야 한다. managed_id 도 고려해야 한다
#2021.08부터 request_routing_rule 블럭에 Priority value가 필요하다
#애플리케이션 게이트웨이가 생성되면 다음과 같은 새 기능을 볼 수 있습니다.
# *appGatewayBackendPool - 애플리케이션 게이트웨이에 백 엔드 주소 풀이 하나 이상 있어야 합니다.
# *appGatewayBackendHttpSettings - 포트 80 및 HTTP 프로토콜을 통신에 사용하도록 지정합니다.
# *appGatewayHttpListener - appGatewayBackendPool에 연결되는 기본 수신기입니다.
# *appGatewayFrontendIP - myAGPublicIPAddress를 appGatewayHttpListener에 할당합니다.
# *rule1 - appGatewayHttpListener에 연결되는 기본 라우팅 규칙입니다.
#(2022.08.17)AppGW를 이용한 WAF구성은 Appgw내부의 WAF configuration{}을 이용하거나 별도의 azurerm_web_application_firewall_policy 리소스를 이용하는 방법이 있다
#Application Gateway가 인증서를 가져올 수 없는 경우 연결된 HTTPS 수신기는 비활성화된 상태가 됩니다. 
############### 진행중  ########################

# Locals block for hardcoded names
locals {
  sku_name = "WAF_v2" #Sku with WAF is : WAF_v2, "Standard_v2"
  sku_tier = "WAF_v2"  #"Standard_v2"
  zones    = ["1", "2", "3"] #Availability zones to spread the Application Gateway over. They are also only supported for v2 SKUs.
  capacity = {
    min = 1 #Minimum capacity for autoscaling. Accepted values are in the range 0 to 100.
    max = 3 #Maximum capacity for autoscaling. Accepted values are in the range 2 to 125.
  }
  appname = "ggsite1"
  backend_address_pool = {
    name  = "${local.appname}-pool1"
    fqdns = ["ggsite1.azurewebsites.net"]
  }

  backend_address_pool_name      = "${azurerm_virtual_network.aks_vnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.aks_vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.aks_vnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.aks_vnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.aks_vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.aks_vnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.aks_vnet.name}-rdrcfg"

  diag_appgw_logs = [
    "ApplicationGatewayAccessLog",
    "ApplicationGatewayPerformanceLog",
    "ApplicationGatewayFirewallLog",
  ]
  diag_appgw_metrics = [
    "AllMetrics",
  ]
}
/*
resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rge.location
  address_space       = ["10.31.0.0/16"]
}
*/
resource "azurerm_subnet" "frontendagw" {
  name                 = "frontend_agw_subnet"
  resource_group_name  = azurerm_resource_group.aks_rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = ["10.31.4.0/24"]
}

/*
resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.31.5.0/24"]
}
*/

resource "azurerm_public_ip" "agw" {
  name                = "${var.prefix}-agw-pip"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.default_tags
}

# - Managed Service Identity
resource "azurerm_user_assigned_identity" "agw" {
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  name                = "${var.prefix}-agw1-msi"
  tags                = var.default_tags
}

resource "time_sleep" "wait_60_seconds" {
  depends_on = [azurerm_key_vault.aks_kv]

  create_duration = "60s"
}

# -
# - Application Gateway (L7 load balancer) and WAF
# -
resource "azurerm_application_gateway" "agw" {
  depends_on          = [azurerm_key_vault_certificate.aks_kvcert, time_sleep.wait_60_seconds]
  #depends_on = [time_sleep.wait_60_seconds]
  name                = "${var.prefix}-prd-agw1"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  enable_http2        = false   #true
  #zones               = local.zones
  tags                = var.default_tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.global.id

  sku {
    name = local.sku_name   #Possible values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, and WAF_v2.
    tier = local.sku_tier   #Possible values are Standard, Standard_v2, WAF and WAF_v2.
    #capacity = 2           #Possible values are 1 to 32 for a V1 SJU, and 1 to 125 for a V2 SKU. autoscale이 있으면 불필요
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
    name      = "${var.prefix}-agw1-ip-configuration"
    subnet_id = azurerm_subnet.frontendagw.id
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


  backend_http_settings {
    name                  = "${local.http_setting_name}-80"
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    host_name             = local.backend_address_pool.fqdns[0]
    request_timeout       = 10
  }

  backend_http_settings {
    name                  = "${local.http_setting_name}-443"
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 443
    protocol              = "Https"
    host_name             = local.backend_address_pool.fqdns[0]
    request_timeout       = 60
  }

  http_listener {
    name                           = "${local.listener_name}-http"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}-public"
    frontend_port_name             = "${local.frontend_port_name}-80"
    protocol                       = "Http"
    firewall_policy_id  = azurerm_web_application_firewall_policy.appgwrule1.id
  }

  request_routing_rule {          
    name                        = "${local.request_routing_rule_name}-http"
    rule_type                   = "Basic"     #Possible values are Basic and PathBasedRouting, `Basic` - This type of listener listens to a single domain site
    http_listener_name          = "${local.listener_name}-http"
    #backend_address_pool_name   = local.backend_address_pool_name   #Cannot be set if redirect_configuration_name is set
    #backend_http_settings_name  = local.http_setting_name           ##Cannot be set if redirect_configuration_name is set
    priority = 1
    redirect_configuration_name = local.redirect_configuration_name
    #url_path_map_name          = "urlmap"
  }
/*
  url_path_map {
    name  = "${local.request_routing_rule_name}-urlmap"
    default_backend_address_pool_name = local.backend_address_pool_name
    default_backend_http_settings_name = local.http_setting_name
  
    path_rule {
      name = "test"
      paths = ["/path1/"]
      backend_address_pool_name = local.backend_address_pool_name
      backend_http_settings_name = local.http_setting_name
    }
  }
*/
/*
## TLS termination (SSL Offloading) using certificate chain PFX file
  ssl_certificates = {
    name     = "appgw-testgateway-ssl01"
    data     = "./keyBag.pfx"
    password = "P@$$w0rd123"
  }
*/

## TLS termination (SSL Offloading) using Key vault inside certificate chain PFX file
  ssl_certificate {
    name                = azurerm_key_vault_certificate.aks_kvcert.name
    key_vault_secret_id = azurerm_key_vault_certificate.aks_kvcert.secret_id  #need to enable soft delete for keyvault to use this feature. 
  }

  http_listener {
    name                           = "${local.listener_name}-https"
    frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}-public"
    frontend_port_name             = "${local.frontend_port_name}-443"
    protocol                       = "Https"
    ssl_certificate_name           = azurerm_key_vault_certificate.aks_kvcert.name
    firewall_policy_id  = azurerm_web_application_firewall_policy.appgwrule1.id
  }

  request_routing_rule {
    name                       = "${local.request_routing_rule_name}-https"
    rule_type                  = "Basic"
    http_listener_name         = "${local.listener_name}-https"
    backend_address_pool_name  = local.backend_address_pool.name
    backend_http_settings_name = "${local.http_setting_name}-443"
    priority = 2
  }

  redirect_configuration {
    name                 = local.redirect_configuration_name
    redirect_type        = "Permanent"
    include_path         = true
    include_query_string = true
    target_listener_name = "${local.listener_name}-https"
  }

/*
  waf_configuration {
    enabled                  = true
    firewall_mode            = "Detection"  #Possible values are Detection and Prevention
    rule_set_type            = "OWASP"      #Currently, only OWASP is supported.
    rule_set_version         = "3.1"        #Possible values are 2.2.9, 3.0, 3.1, and 3.2
    file_upload_limit_mb     = 100          #Defaults to 100MB.Accepted values are in the range 1MB to 750MB for the WAF_v2 SKU
    max_request_body_size_kb = 128          #Defaults to 128KB
  /*
    disabled_rule_group = [
      {
        rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"
        rules           = ["930100", "930110"]
      },
      {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules           = ["920160"]
      }
    ]

    exclusion = [
      {
        match_variable          = "RequestCookieNames" #Possible values are RequestHeaderNames, RequestArgNames and RequestCookieNames
        selector                = "SomeCookie"
        selector_match_operator = "Equals"            #Possible values are Equals, StartsWith, EndsWith, Contains
      },
      {
        match_variable          = "RequestHeaderNames"
        selector                = "referer"
        selector_match_operator = "Equals"
      }
    ]
  */
/*
    #Ref:https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/web_application_firewall_policy
    custom_policies = [           
        {
        name      = "AllowRefererBeginWithExample"
        priority  = 1
        rule_type = "MatchRule"
        action    = "Allow"

        match_conditions = [
            {
            match_variables = [
                {
                match_variable = "RequestHeaders"
                selector       = "referer"
                }
            ]

            operator           = "BeginsWith"
            negation_condition = false
            match_values       = ["https://example.com"]
            }
        ]
        },
        
        {    
        name      = "Rule2"
        priority  = 2
        rule_type = "MatchRule"
        action    = "Block"

        match_conditions = [
            {
            match_variables =[{
                variable_name = "RemoteAddr"
                }
            ]
            operator           = "IPMatch"
            negation_condition = false
            match_values       = ["192.168.1.0/24", "10.0.0.0/24"]
            }

        ]
        }
    ]
  */
#  } 


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
      #ssl_certificate,
      redirect_configuration,
      autoscale_configuration
    ]
  }
}
#If you want a custom rule then you need to break off the rules into a separate azurerm_web_application_firewall_policy. 
#This can then be referenced back in the azurerm_application_gateway through the firewall_policy_id
### Web application firewall settings - WAF policy config for per site
resource "azurerm_web_application_firewall_policy" "global" {
  name                = "global-wafpolicy"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  tags                = var.default_tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {

    managed_rule_set {
      type                        = "OWASP"
      version                     = "3.1"
    }
  }

}


resource "azurerm_web_application_firewall_policy" "appgwrule1" {
  name                = "appgw1-wafpolicy"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  tags                = var.default_tags

  custom_rules {
    name      = "OnlyUSandCanada"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = ["CA", "US"]
    }
    action = "Block"
  }

  policy_settings {
    enabled = true
    mode    = "Detection"           #"Prevention"
    # Global parameters
    request_body_check          = true
    max_request_body_size_in_kb = 128
    file_upload_limit_in_mb     = 100
  }
  
  managed_rules {
    exclusion {
      match_variable          = "RequestHeaderNames"
      selector                = "x-company-secret-header"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestCookieNames"
      selector                = "too-tasty"
      selector_match_operator = "EndsWith"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.1"
      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        disabled_rules = [
          "920300",
          "920440"
        ]
      }
    }
  }

}


# -
# - Log Analytics Workspace  : Azure Monitor는 Log Analytics 작업 영역에 설치된 각 솔루션에 대한 타일이 표시됩니다
# -
resource "azurerm_log_analytics_workspace" "wks" {
  name                = "${var.prefix}-hub-logagw1"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku                 = "PerGB2018" #(Required) Specifies the Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018 (new Sku as of 2018-04-03).
  retention_in_days   = 31         #(Optional) The workspace data retention in days. Possible values range between 30 and 730.
  tags                = var.default_tags
}

resource "azurerm_log_analytics_solution" "agw" {
  solution_name         = "AzureAppGatewayAnalytics"
  location              = azurerm_resource_group.aks_rg.location
  resource_group_name   = azurerm_resource_group.aks_rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.wks.id
  workspace_name        = azurerm_log_analytics_workspace.wks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/AzureAppGatewayAnalytics"
  }
}

# -
# Diagnostic Settings
# -
resource "azurerm_monitor_diagnostic_setting" "agw" {
  name                       = "${var.prefix}-agw1-diag"
  target_resource_id         = azurerm_application_gateway.agw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.wks.id
  dynamic "log" {
    for_each = local.diag_appgw_logs
    content {
      category = log.value

      retention_policy {
        enabled = false
      }
    }
  }

  dynamic "metric" {
    for_each = local.diag_appgw_metrics
    content {
      category = metric.value

      retention_policy {
        enabled = false
      }
    }
  }
}

output "appgw_public_ip" {
  value = azurerm_public_ip.agw.public_ip_address_id
}

output "secret_identifier" {
  value = azurerm_key_vault_certificate.aks_kvcert.secret_id
}