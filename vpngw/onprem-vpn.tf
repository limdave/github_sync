#Create Single VPN Gateway from on-prem to onCloud (default Active-Standby)
#https://docs.microsoft.com/ko-kr/azure/developer/terraform/hub-spoke-on-prem
#Tested by 2022.01.26 limgongsik.

locals {
  onprem-location       = "westus2"
  onprem-resource-group = "rg-onprem-vnet"
  prefix-onprem         = "onprem"
  shared-key            = "vpnkey!@#"
}

resource "azurerm_resource_group" "onprem-vnet-rg" {
  name     = local.onprem-resource-group
  location = local.onprem-location
  tags = var.tags
}

#Azure Hub's Network
resource "azurerm_virtual_network" "oncloud-vnet" {
  name                = "oncloud-vnet"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  address_space       = ["10.90.90.0/24"]

  tags = var.tags
}

resource "azurerm_subnet" "oncloud-workload" {
  name                 = "oncloud-workload"
  resource_group_name  = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.oncloud-vnet.name
  address_prefixes     = ["10.90.90.0/27"]
}

resource "azurerm_subnet" "oncloud-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.oncloud-vnet.name
  address_prefixes     = ["10.90.90.224/27"]
}

resource "azurerm_public_ip" "oncloud-vpn-gateway1-pip" {
  name                = "oncloud-vpn-gateway1-pip"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  allocation_method   = "Dynamic"
  #sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_virtual_network_gateway" "oncloud-vpn-gateway" {
  name                = "oncloud-vpn-gateway"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

  type     = "Vpn"          #Valid options are Vpn or ExpressRoute
  vpn_type = "RouteBased"   #Valid options are RouteBased or PolicyBased

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"  # Valid options are Basic, Standard, HighPerformance, UltraPerformance, ErGw1AZ, ErGw2AZ, ErGw3AZ, VpnGw1, VpnGw2, VpnGw3, VpnGw4,VpnGw5, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ,VpnGw4AZ and VpnGw5AZ

  ip_configuration {        #ip_config is one for A-S, two for A-A
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.oncloud-vpn-gateway1-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.oncloud-gateway-subnet.id
  }
  depends_on = [azurerm_public_ip.oncloud-vpn-gateway1-pip]
}

#on-prem site's Network
resource "azurerm_virtual_network" "onprem-vnet" {
  name                = "onprem-vnet"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  address_space       = ["192.168.0.0/16"]

  tags = var.tags
}

/*
resource "azurerm_subnet" "onprem-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefixes     = ["192.168.255.224/27"]
}
*/
resource "azurerm_subnet" "onprem-workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefixes     = ["192.168.0.0/24"]
}

resource "azurerm_subnet" "onprem-mgmt" {
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefixes     = ["192.168.1.0/24"]
}

#on-prem workload's element of vm
resource "azurerm_public_ip" "onprem-pip" {
    name                = "${local.prefix-onprem}-pip"
    location            = azurerm_resource_group.onprem-vnet-rg.location
    resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
    allocation_method   = "Dynamic"      #Static
    #sku                 = "Standard"

    tags = var.tags
}

resource "azurerm_network_interface" "onprem-nic" {
  name                 = "${local.prefix-onprem}-nic"
  location             = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name  = azurerm_resource_group.onprem-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = local.prefix-onprem
    subnet_id                     = azurerm_subnet.onprem-workload.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.onprem-pip.id
  }
}

# Create Network Security Group and rule of vm
resource "azurerm_network_security_group" "onprem-nsg" {
    name                = "${local.prefix-onprem}-nsg"
    location            = azurerm_resource_group.onprem-vnet-rg.location
    resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
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
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "wk-nsg-association" {
  subnet_id                 = azurerm_subnet.onprem-workload.id
  network_security_group_id = azurerm_network_security_group.onprem-nsg.id
}

#on-prem workload's vm
resource "azurerm_linux_virtual_machine" "onprem-vm" {
    name                  = "${local.prefix-onprem}-vm1"
    location              = azurerm_resource_group.onprem-vnet-rg.location
    resource_group_name   = azurerm_resource_group.onprem-vnet-rg.name
    network_interface_ids = [azurerm_network_interface.onprem-nic.id]
    size                  = var.vmsize

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_disk {
        name              = "onpremosdisk2"
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    computer_name  = "${local.prefix-onprem}-vm1"
    admin_username = var.username
    admin_password = var.password
    disable_password_authentication = false

    tags = var.tags
}

#---------------
#On-Prem VPN (local gateway)
resource "azurerm_public_ip" "onprem-vpn-gateway1-pip" {
  name                = "${local.prefix-onprem}-vpn-gateway1-pip"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_public_ip" "onprem-vpn-gateway2-pip" {      #2nd IP address for Active-Active VPN connection
    name                = "${local.prefix-onprem}-vpn-gateway2-pip"
    location            = azurerm_resource_group.onprem-vnet-rg.location
    resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
    allocation_method   = "Static"
    sku                 = "Standard"

    tags = var.tags
}
/*
#on-prem이 VPN Gateway 역할을 할때 사용할 코드
resource "azurerm_virtual_network_gateway" "onprem-vpn-gateway" {
  name                = "${local.prefix-onprem}-vpn-gateway1"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem-vpn-gateway1-pip1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem-gateway-subnet.id
  }
  depends_on = [azurerm_public_ip.onprem-vpn-gateway1-pip]

}
*/

# Local network gateway to azure virtual network gateway
resource "azurerm_local_network_gateway" "onprem-vpn-localgw" {
  name                = "onprem-vpn-localgw"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  address_space       = ["192.168.0.0/24",]   ## on-prem's local network subnet address
  gateway_address     = "XXX.151.57.2"         ##--Your local device public IP here   /azurerm_public_ip.onprem-vpn-gateway1-pip.id
  
  #bgp_settings {
  #  asn                 = azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].asn
  #  bgp_peering_address = tolist(azurerm_vpn_gateway.VPNGW-HUB-WestEurope.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[0]
  #}
  tags = var.tags
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "onprem-hub-conn" {
  name                = "onprem-cloudhub-conn"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

  type           = "IPsec"      

  virtual_network_gateway_id  = azurerm_virtual_network_gateway.oncloud-vpn-gateway.id
  local_network_gateway_id    = azurerm_local_network_gateway.onprem-vpn-localgw.id

  shared_key = local.shared-key
}

/*
#IPSec VPN이 아닌 Azure의 Virtual network간의 VPN Gateway를 이용한 Vnet간 연결인 경우에 사용하는 코드로 쌍방의 연결이 2개 필요
#shows a connection between two Azure virtual network in different locations/regions.
resource "azurerm_virtual_network_gateway_connection" "branch-hub-conn" {
  name                = "branch-hub-conn"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  type                = "Vnet2Vnet"
  routing_weight = 10           #default value is 10
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.onprem-vpn-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.hub-vnet-gateway.id

  shared_key = local.shared-key
}

resource "azurerm_virtual_network_gateway_connection" "hub-branch-conn" {
  name                = "hub-branch-conn"
  location            = azurerm_resource_group.onprem-vnet-rg.location
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  type                = "Vnet2Vnet"
  routing_weight = 10
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.hub-vnet-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem-vpn-gateway.id

  shared_key = local.shared-key
}
*/