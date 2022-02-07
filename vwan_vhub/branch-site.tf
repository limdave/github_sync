# This configuration deploys the non-essential part of the vWAN
# I use it to simulate the branch site for the lab topology :: https://docs.microsoft.com/en-us/azure/virtual-wan/connect-virtual-network-gateway-vwan
# It is just a VNET with VPN Gateway and VPN connection to vWAN
# Creating a connection from a VPN Gateway (virtual network gateway) to a Virtual WAN (VPN gateway) is similar to setting up connectivity to a virtual WAN from branch VPN sites.

#locals {
#  shared-key = "4-v3ry-53cr37-k3y"
#  branch_asn = 65400 / 64456
#}
locals {
    branch-location       = "eastus2"
    branch-resource-group = "rg-branch1-vnet"
    prefix-branch         = "branch1"

    shared-key2 = "vpnkey$2022"
    branch_asn = 65400

    vwan_asn = 65515
}

resource "azurerm_resource_group" "branch1-vnet-rg" {
    name     = local.branch-resource-group
    location = local.branch-location

    tags = var.tags
}

# Public IP for VPN Gateway (branch)
resource "azurerm_public_ip" "vnet-branch-vpngw-publicip1" {
  name                = "vnet-branch-vpngw-publicip1"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags              = var.tags
}

resource "azurerm_public_ip" "vnet-branch-vpngw-publicip2" {
  name                = "vnet-branch-vpngw-publicip2"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags              = var.tags
}

# Branch VNet
resource "azurerm_virtual_network" "vnet-branch-1" {
  name                = "vnet-branch-1"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  address_space       = ["192.168.10.0/24","192.168.11.0/24"]
  tags                = var.tags
}

resource "azurerm_subnet" "vnet-branch-1-subnet-1" {
  name                 = "net-branch-1-subnet-1"
  resource_group_name  = azurerm_resource_group.branch1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.vnet-branch-1.name
  address_prefixes     = ["192.168.10.0/26"]
}

resource "azurerm_subnet" "vnet-branch-1-subnet-2" {
  name                 = "net-branch-1-subnet-2"
  resource_group_name  = azurerm_resource_group.branch1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.vnet-branch-1.name
  address_prefixes     = ["192.168.10.64/26"]
}

# Gateway subnet for VPN Gateway
resource "azurerm_subnet" "vnet-branch-1-subnet-gw" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.branch1-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.vnet-branch-1.name
  address_prefixes     = ["192.168.11.0/27"]   #192.168.10.224/27
}

# VPN Gateway - we are using the small one to not generate cost. The BGP must be active
resource "azurerm_virtual_network_gateway" "vnet-branch-1-vpngw" {
  name                = "vnet-branch-1-vpngw"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  type                = "vpn"
  vpn_type            = "RouteBased"
  #generation          = "Generation1"
  sku                 = "VpnGw1AZ"
  enable_bgp          = true
  active_active       = true    #for vwan with bgp : true
  bgp_settings {
    asn = local.branch_asn
  }
  ip_configuration {
    name                 = "vnet-branch-1-ipconfig-1"
    public_ip_address_id = azurerm_public_ip.vnet-branch-vpngw-publicip1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id            = azurerm_subnet.vnet-branch-1-subnet-gw.id
  }
  ip_configuration {
    name                 = "vnet-branch-1-ipconfig-2"
    public_ip_address_id = azurerm_public_ip.vnet-branch-vpngw-publicip2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id            = azurerm_subnet.vnet-branch-1-subnet-gw.id
  }
  tags = var.tags
}

# Local network gateway to define the vWAN Hub side
/*
resource "azurerm_local_network_gateway" "vpn-to-vwan-hub" {
  name                = "vpn-to-vwan-hub"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  address_space       = ["192.168.10.0/24"]
  gateway_address     = azurerm_vpn_gateway.example-wanvpn.ip

  bgp_settings {
    asn                 = local.branch_asn
    bgp_peering_address = azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0]
    #peer_weight
  }
  tags = var.tags
}

resource "azurerm_local_network_gateway" "vpn-to-vwan-hub" {
  name                = "vpn-to-vwan-hub"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  address_space       = ["${tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[0]}/32"]
  gateway_address     = tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]

  bgp_settings {
    asn                 = local.branch_asn
    bgp_peering_address = tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[0]
  }
  tags = var.tags
}
*/
/*참고용 보관
resource "azurerm_local_network_gateway" "vpn-to-vwan-hub" {
  name                = "vpn-to-vwan-hub"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  address_space       = ["${tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[0]}/32"]
  gateway_address     = tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]

  bgp_settings {
    asn                 = local.branch_asn
    bgp_peering_address = tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[0]
  }
  tags = var.tags
}
*/
# VPN Connection
/*
resource "azurerm_virtual_network_gateway_connection" "branch-to-hub-vpn" {
  name                = "branch-to-hub-vpn"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name

  type       = "IPsec"
  enable_bgp = true

  virtual_network_gateway_id = azurerm_virtual_network_gateway.vnet-branch-1-vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.vpn-to-vwan-hub.id

  shared_key = local.shared-key2
  tags       = var.tags
}
*/
#################
# The vWAN part of the connection
#################
/*
resource "azurerm_vpn_gateway" "microhack-we-hub-vng" {
  name                = "microhack-we-hub-vng"
  location            = var.location-vwan-we-hub
  resource_group_name = azurerm_resource_group.vwan-microhack-hub-rg.name
  virtual_hub_id      = azurerm_virtual_hub.microhack-we-hub.id
}
*/

# Site definition (of branch-1)

resource "azurerm_vpn_site" "branch-1-vpn" {
  name                = "branch-1-site"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name
  virtual_wan_id      = azurerm_virtual_wan.vwan-demo.id

  link {
    name       = "link1"
    ip_address = azurerm_public_ip.vnet-branch-vpngw-publicip1.ip_address
    bgp {
      asn             = azurerm_virtual_network_gateway.vnet-branch-1-vpngw.bgp_settings[0].asn
      #peering_address = azurerm_virtual_network_gateway.vnet-branch-1-vpngw.bgp_settings[0].peering_address
      peering_address = "192.168.11.4"
    }
  }
    link {
    name       = "link2"
    ip_address = azurerm_public_ip.vnet-branch-vpngw-publicip2.ip_address
    bgp {
      asn             = azurerm_virtual_network_gateway.vnet-branch-1-vpngw.bgp_settings[0].asn
      #peering_address = azurerm_virtual_network_gateway.vnet-branch-1-vpngw.bgp_settings[0].peering_address
      peering_address = "192.168.11.5"
    }
  }
}



# Then we connect the site to vWAN hub
resource "azurerm_vpn_gateway_connection" "vpn-vwan-to-branch-1-connection" {
  name               = "vpn-vwan-to-branch-1-connection"
  vpn_gateway_id     = azurerm_vpn_gateway.VPNGW-HUB-WestEurope.id
  remote_vpn_site_id = azurerm_vpn_site.branch-1-vpn.id

  vpn_link {
    name             = "link1"
    vpn_site_link_id = azurerm_vpn_site.branch-1-vpn.link[0].id
    shared_key       = local.shared-key2
    bgp_enabled      = true
  }
    vpn_link {
    name             = "link2"
    vpn_site_link_id = azurerm_vpn_site.branch-1-vpn.link[1].id
    shared_key       = local.shared-key2
    bgp_enabled      = true
  }
}

#######################################################################
## Create Network Interface - Spoke branch
#######################################################################
resource "azurerm_public_ip" "branch1-vm-pub-ip" {
    name                 = "branch1-vm-pub-ip"
    location             = azurerm_resource_group.branch1-vnet-rg.location
    resource_group_name  = azurerm_resource_group.branch1-vnet-rg.name
    allocation_method   = "Static"
    sku = "Standard"
    tags = var.tags
}

resource "azurerm_network_interface" "branch1-nic" {
  name                 = "branch-nic"
  location             = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name  = azurerm_resource_group.branch1-vnet-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "branch1-ipconfig"
    subnet_id                     = azurerm_subnet.vnet-branch-1-subnet-1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.branch1-vm-pub-ip.id
  }

  tags = var.tags
  
}
#On-prem NSG
resource "azurerm_network_security_group" "branch1-nsg" {
  name                = "branch1-nsg"
  location            = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name = azurerm_resource_group.branch1-vnet-rg.name

  security_rule {
    name                       = "RDP-In"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = var.tags
  
}
#NSG Association to all On-prem Subnets
resource "azurerm_subnet_network_security_group_association" "branch1-nsg-associate" {
  subnet_id                 = azurerm_subnet.vnet-branch-1-subnet-1.id
  network_security_group_id = azurerm_network_security_group.branch1-nsg.id
}

#######################################################################
## Create Virtual Machine branch onprem
#######################################################################
resource "azurerm_windows_virtual_machine" "branch1-vm" {
  name                  = "branch1-vm"
  location              = azurerm_resource_group.branch1-vnet-rg.location
  resource_group_name   = azurerm_resource_group.branch1-vnet-rg.name
  network_interface_ids = [azurerm_network_interface.branch1-nic.id]
  size               = var.vmsize
  computer_name  = "branch1-vm"
  admin_username = var.username
  admin_password = var.password
  provision_vm_agent = true

  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    name              = "branch1-osdisk"
    caching           = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  tags = var.tags
}
