# The Azure Virtual WAN (vWAN) configuration.
# Reference : https://github.com/SzkolaDevNet/Terraform-Azure-vWAN
# https://marckean.com/2021/08/01/terraform-azure-virtual-wan-no-azure-firewall/
# # 보안허브는 firewall-manager를 이용해서 생성해야 한다. 현재 Terraform code로는 바로 보안허브를 생성할 수 없다.
# 2022.01.28 limgongsik
#
locals {
    hub01-location       = "eastus2"
    hub01-resource-group = "rg-vwan-hub01"
    prefix-hub01         = "hub01"
    prefix-vwan          = "vwan03"
}

resource "azurerm_resource_group" "demo1-vwan-rg" {
    name     = local.hub01-resource-group
    location = local.hub01-location

    tags = var.tags
}

# VNets configuration for vWAN Hubs another network
# VNet definitions
resource "azurerm_virtual_network" "vnet-4" {
  name                = "vnet-4"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  address_space       = ["10.70.0.0/24"]
  tags                = var.tags
}

# Subnet definitions - this is not essential but may be used in future
# if in larger demo we decide to have VMs or other Azure services that requires proper networking, not just VNets
resource "azurerm_subnet" "vnet-4-subnet-1" {
  name                 = "vnet-4-subnet-1"
  resource_group_name  = azurerm_resource_group.demo1-vwan-rg.name
  virtual_network_name = azurerm_virtual_network.vnet-4.name
  address_prefixes     = ["10.70.0.0/27"]
}

resource "azurerm_network_security_group" "vnet-4-nsg" {
  name                = "vnet-4-nsg"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
}

resource "azurerm_subnet" "examplesubnet" {
  name                 = "examplesubnet"
  resource_group_name  = azurerm_resource_group.demo1-vwan-rg.name
  virtual_network_name = azurerm_virtual_network.vnet-4.name
  address_prefixes     = ["10.70.0.32/27"]
}

resource "azurerm_subnet_network_security_group_association" "vnet-4-nsg-associate" {
  subnet_id                 = azurerm_subnet.vnet-4-subnet-1.id
  network_security_group_id = azurerm_network_security_group.vnet-4-nsg.id
}


# It contains one vWAN servie with one hubs.
resource "azurerm_virtual_wan" "vwan-demo" {
  name                = "${prefix-vwan}"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name

  #disable_vpn_encryption            = var.disable_vpn_encryption               #default : false
  #allow_vnet_to_vnet_traffic        = var.allow_vnet_to_vnet_traffic           #default : false - x
  #allow_branch_to_branch_traffic    = var.allow_branch_to_branch_traffic       #default : true
  #office365_local_breakout_category = var.office365_local_breakout_category    #default : None
  tags                = var.tags
}

resource "azurerm_virtual_hub" "vhub-01" {
  name                = "${prefix-vwan}-hub-eus2"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  virtual_wan_id      = azurerm_virtual_wan.vwan-demo.id
  address_prefix      = "10.90.0.0/24"    # virtual hub ip address

  tags                = var.tags
}

# Create VPN Gateway of vWAN VPN Site
resource "azurerm_vpn_gateway" "vpngw-hub-01" {
  name                = "vpngw-hub-01"
  location            = azurerm_resource_group.demo1-vwan-rg.location
  resource_group_name = azurerm_resource_group.demo1-vwan-rg.name
  virtual_hub_id      = azurerm_virtual_hub.vhub-01.id
  tags                = var.tags
}

# Connect VNETs to HUBs
resource "azurerm_virtual_hub_connection" "spoke1-to-hub" {
  name                      = "spoke1-to-hub"
  remote_virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
  virtual_hub_id            = azurerm_virtual_hub.vhub-01.id
}

resource "azurerm_virtual_hub_connection" "spoke2-to-hub" {
  name                      = "spoke2-to-hub"
  remote_virtual_network_id = azurerm_virtual_network.spoke2-vnet.id
  virtual_hub_id            = azurerm_virtual_hub.vhub-01.id
}

resource "azurerm_virtual_hub_connection" "vnet-4-to-hub" {
  name                      = "vnet-4-to-hub"
  remote_virtual_network_id = azurerm_virtual_network.vnet-4.id
  virtual_hub_id            = azurerm_virtual_hub.vhub-01.id
}


# virtual hub connection and route table
resource "azurerm_virtual_hub_route_table" "example-vhubroute" {
  name           = "example-vhubroutetable"
  virtual_hub_id = azurerm_virtual_hub.vhub-01.id
  labels         = ["label1"]

  route {               #this is same about "azurerm_virtual_hub_route_table_route"
    name              = "example-route"
    destinations_type = "CIDR"                  #Possible values are CIDR, ResourceId and Service
    destinations      = ["10.90.0.0/16"]
    next_hop_type     = "ResourceId"
    next_hop          = azurerm_virtual_hub_connection.vnet-4-to-hub-hub.id
  }

}

/* examples
resource "azurerm_virtual_hub_connection" "eastus_vnet_to_eastus_vHub" {
  name                      = "eastus_vnet_to_eastus_vHub"
  virtual_hub_id            = azurerm_virtual_hub.eastus_vHub.id
  remote_virtual_network_id = azurerm_virtual_network.mre_az_eastus_hub1_usse.id 
  
  routing  {
      associated_route_table_id = azurerm_virtual_hub_route_table.eastus_vHub_rtb.id
      propagated_route_table {
        route_table_ids= [azurerm_virtual_hub_route_table.westeu_vHub_rtb.id, azurerm_virtual_hub_route_table.eastus_vHub_rtb.id]
      }
    }
}
*/



/*
resource "azurerm_virtual_hub_security_partner_provider" "example" {
  name                   = "example-spp"
  resource_group_name    = azurerm_resource_group.example.name
  location               = azurerm_resource_group.example.location
  virtual_hub_id         = azurerm_virtual_hub.example.id
  security_provider_name = "IBoss"      #Possible values are ZScaler, IBoss and Checkpoint

  tags = {
    ENV = "Prod"
  }

  depends_on = [azurerm_vpn_gateway.example]
}


#vpn_gateway examples
resource "azurerm_vpn_gateway" "example" {
  name                = "example-vpngw"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  virtual_hub_id      = azurerm_virtual_hub.example.id
}

resource "azurerm_vpn_site" "example" {
  name                = "example-vpn-site"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  virtual_wan_id      = azurerm_virtual_wan.example.id
  link {
    name       = "link1"
    ip_address = "10.1.0.0"
  }
  link {
    name       = "link2"
    ip_address = "10.2.0.0"
  }
}

resource "azurerm_vpn_gateway_connection" "example" {
  name               = "example"
  vpn_gateway_id     = azurerm_vpn_gateway.example.id
  remote_vpn_site_id = azurerm_vpn_site.example.id

  vpn_link {
    name             = "link1"
    vpn_site_link_id = azurerm_vpn_site.example.link[0].id
  }

  vpn_link {
    name             = "link2"
    vpn_site_link_id = azurerm_vpn_site.example.link[1].id
  }
}
*/

/*
#아래는 vwan의 VPN Site가 아닌 일반Vnet에 VPNGW구성하는 것임
# Virtual Network Gateway
resource "azurerm_public_ip" "hub-vpn-gateway1-pip" {
  name                = "hub-vpn-gateway1-pip"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "hub-vnet-gateway" {
  name                = "hub-vpn-gateway1"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false       #vhub에서의 VPN은 bgp가 구성되어 있어야 한다. ANS번호 필요함
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.hub-vpn-gateway1-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub-gateway-subnet.id
  }
  depends_on = [azurerm_public_ip.hub-vpn-gateway1-pip]
}

resource "azurerm_virtual_network_gateway_connection" "hub-onprem-conn" {
  name                = "hub-onprem-conn"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  type           = "Vnet2Vnet"
  routing_weight = 1

  virtual_network_gateway_id      = azurerm_virtual_network_gateway.hub-vnet-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem-vpn-gateway.id

  shared_key = local.shared-key
}

resource "azurerm_virtual_network_gateway_connection" "onprem-hub-conn" {
  name                = "onprem-hub-conn"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  type                            = "Vnet2Vnet"
  routing_weight = 1
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.onprem-vpn-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.hub-vnet-gateway.id

  shared_key = local.shared-key
}
*/