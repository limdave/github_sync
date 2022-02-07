#Azure Firewall Setup
#Public IP
resource "azurerm_public_ip" "region1-fw01-pip" {
  name                = "region1-fw01-pip"
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  location            = azurerm_resource_group.demo1-vwan-rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags

}

/*
resource "azurerm_virtual_hub" "HUB-WestUS" {
  name                = "HUB-WestUS"
  address_prefix      = "10.90.0.0/16"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  virtual_wan_id      = azurerm_virtual_wan.vwan-demo.id
  tags                = var.tags
}

resource "azurerm_virtual_network" "example" {
  name                = "testvnet"
  address_space       = ["10.90.0.0/16"]
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
}

resource "azurerm_subnet" "region1-fw01-sbnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.demo1-vwan-rg.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.90.1.0/24"]
}

#Azure Firewall Instance
#20200613이후 azurerm_firewallmanager_securevirtualhub 이용
#20220126 임공식 - subnet_id를 필요로하나 생성매핑할 수 없음. 고로 fw policy만 만들고 portal에서 보안허브로 FW생성해야함
resource "azurerm_firewall" "region1-fw01" {
  name                = "region1-fw01"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  sku_tier = "Premium"      #Possible values are Premium and Standard
  sku_name = "AZFW_Hub"      #To use the Secure Virtual Hub : AZFW_Hub , AZFW_VNet
  threat_intel_mode = ""     #if virtual_hub set, value is ""
  
  firewall_policy_id  = azurerm_firewall_policy.region1-fw-pol01.id

  ip_configuration {
    name                 = "fw-ipconfig"
    #subnet_id            = azurerm_subnet.region1-vnet1-snetfw.id
    subnet_id            = azurerm_subnet.region1-fw01-sbnet.id
    public_ip_address_id = azurerm_public_ip.region1-fw01-pip.id
  }
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.HUB-WestUS.id
    public_ip_count = 1   #default=1
  }
  tags = var.tags
}
*/

#it’s the Application, Netowrk, and Policy Rule Collection Groups that are most likely to be required.
#Firewall Policy
resource "azurerm_firewall_policy" "region1-fw-pol01" {
  name                = "region1-firewall-policy01"
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  location            = azurerm_resource_group.demo1-vwan-rg.location
  sku = "Premium"

  tags = var.tags
}

# Firewall Policy Rules
# 개별적으로 rule collection 을 생성할 수 있다. azurerm_firewall_application_rule_collection
resource "azurerm_firewall_policy_rule_collection_group" "region1-policy1" {
  name               = "region1-policy1"
  firewall_policy_id = azurerm_firewall_policy.region1-fw-pol01.id
  priority           = 100

  application_rule_collection {
    name     = "application_rule_collection1"
    priority = 500
    action   = "Deny"
    rule {
      name = "blocked_website"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["jakewalsh.co.uk","www.google.com"]
    }
  }

  network_rule_collection {
    name     = "network_rules_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP"]    #Possible values are Any, ICMP, TCP and UDP
      source_addresses      = ["*"]
      destination_addresses = ["10.81.0.0/24", "10.81.1.0/24"]
      destination_ports     = ["80", "3389"]
    }
  }

    nat_rule_collection {
    name     = "nat_rule_collection1"
    priority = 300
    action   = "Dnat"
    rule {
      name                = "nat_rule_collection1_rule1"
      protocols           = ["TCP", "UDP"]    #Dnat, protocols can only be TCP and UDP
      source_addresses    = ["*"]
      #destination_address = "192.168.1.1"
      destination_address = "${azurerm_public_ip.region1-fw01-pip.ip_address}"
      destination_ports   = ["3389",]
      translated_address  = "10.80.0.4"
      translated_port     = "3389"
    }
  }
}

/*
resource "azurerm_firewall_application_rule_collection" "example" {
  name                = "testcollection"
  azure_firewall_name = azurerm_firewall.example.name
  resource_group_name = azurerm_resource_group.example.name
  priority            = 500
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
*/

resource "azurerm_log_analytics_workspace" "fwlogs" {
  name                = "logs-fwprem01"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 31

  tags = var.tags
}
