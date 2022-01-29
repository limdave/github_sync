#create firewall premium
#Azure Firewall provisioning can take until 15 minutes to be up and running.

resource "azurerm_subnet" "ggfwSubnet00" {
    name                 = "AzureFirewallSubnet"
    resource_group_name  = azurerm_resource_group.ggResourcegroup.name
    virtual_network_name = azurerm_virtual_network.ggVnet01.name
    address_prefixes       = ["10.50.1.0/26"]
}


resource "azurerm_public_ip" "ggfwPublic" {
  name                = "fwp-eus-pip"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags    = var.default_tags
}

resource "azurerm_firewall" "ggfirewall" {
  name                = "fwp-eus-tlstest"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  firewall_policy_id  = azurerm_firewall_policy.fwprem-pol.id    #for premium
  sku_tier            = "Premium"                                #for premium , Standard

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.ggfwSubnet00.id
    public_ip_address_id = azurerm_public_ip.ggfwPublic.id
  }

  tags    = var.default_tags
}

resource "azurerm_firewall_policy" "fwprem-pol" {
  name                 = "fwprem-policy"
  resource_group_name  = azurerm_resource_group.ggResourcegroup.name
  location             = azurerm_resource_group.ggResourcegroup.location
  sku                  = "Premium"
  threat_intelligence_mode = "Deny"     #default=Alert

  tags    = {
      created = "${timeadd(timestamp(),"9h")}",
      Owner   = "gslim"
  }
}

# create azure key vault and purge_soft_delete_on_destroy = true
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "example" {
  name                        = "keyvault-fwp"
  location                    = azurerm_resource_group.ggResourcegroup.location
  resource_group_name         = azurerm_resource_group.ggResourcegroup.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = ["get", "list" ]

    secret_permissions = ["get", "list" ]

    certificate_permissions = ["get", "list", "import" ]

    storage_permissions = ["get", "list", "backup", "recover" ]
  }
  
  #storage_account_id         = var.storage_account_id
  tags = var.default_tags
}

/*
  threat_intelligence_allowlist = {
      ip_address = ["10.50.0.4"]          #어떤 IP를 사용하는지???
      fqdn = ["www.google.com"]
  }

  tls_cetificate = {
      ...
  }
  intrusion_detection = {
     mode = "Deny" # "Alert", "Deny", "off"
     configuration = {
       signature_overrides = {
         state = "off" # "Alert", "Deny"
         id = signature_id
         }
       bypass_traffic_settings = {
         name = "bypass_traffic_setting_1"
         description = ""
         protocol = "TCP"
         source_addresses = "*"
         destination_addresses = "*"
         destination_ports = "*"
         source_ip_groups = "*"
         destination_ip_groups = "*"
         }
       }
  }

  transport_security = {
    certificate_authority = {
      key_vault_secret_id = "..." // KeyVaultSecretID - Secret Id of (base-64 encoded unencrypted pfx) 'Secret' or 'Certificate' object stored in KeyVault.
      name = "..." // Name - Name of the CA certificate.
    }
  }
  
  insights = {
      enabled   = "true"
      default_log_analytics_workspace_id = ...
      retention_in_days = 31
    log_analytics_workspace{
    }
  }

  tags = var.default_tags
}
*/

resource "azurerm_log_analytics_workspace" "fwlogs" {
  name                = "logs-eus-fwprem01"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  sku                 = "PerGB2018"
  retention_in_days   = 31

  tags = var.default_tags
}

/*
# Support Create firewall premium features
resource "azurerm_filrewall_policy_rule_collection_group" "rule_collect_gp" {
  name               = "fwrule-collection1"
  firewall_policy_id = azurerm_firewall_policy.fwprem-pol.id
  priority           = 100

  application_rule_collection {
    name     = "blocked_websites1"
    priority = 3000
    action   = "Deny"
    rule {
      name = "dodgy_website"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["jakewalsh.co.uk"]
    }
  }
  network_rule_collection {
    name     = "network_rules1"
    priority = 2000
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["192.168.1.1", "192.168.1.2"]
      destination_ports     = ["80", "8000-8080"]
    }
  }

}

# Create firewall classic rule
resource "azurerm_firewall_application_rule_collection" "app-rc" {
  name                = "apptestcollection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "testrule"

    source_addresses = [
      "10.0.0.0/16",
    ]

    target_fqdns = [
      "*.google.com",
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "net-rc" {
  name                = "nettestcollection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "dnsrule"

    source_addresses = [
      "10.0.0.0/16",
    ]

    destination_ports = [
      "53",
    ]

    destination_addresses = [
      "8.8.8.8",
      "8.8.4.4",
    ]

    protocols = [
      "TCP",
      "UDP",
    ]
  }
}
*/