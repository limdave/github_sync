# aks and vmss examples from "https://github.com/iljoong/azure-terraform"
# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

  features {}
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "tfrg" {
  name     = "${var.prefix}-rg"
  location = var.location

  tags = {
    environment = var.tag
  }
}

# Create virtual network
resource "azurerm_virtual_network" "tfvnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  tags = {
    environment = var.tag
  }
}

resource "azurerm_subnet" "tfaksvnet" {
  name                 = "aks-net"
  virtual_network_name = azurerm_virtual_network.tfvnet.name
  resource_group_name  = azurerm_resource_group.tfrg.name

  # 10.1.0.1 ~ 10.1.15.254
  address_prefix = "10.1.0.0/20"
}

resource "azurerm_subnet_network_security_group_association" "tfaksvnet" {
  subnet_id                 = azurerm_subnet.tfaksvnet.id
  network_security_group_id =  azurerm_network_security_group.tfaksnsg.id
}

resource "azurerm_subnet_route_table_association" "tfaksvnet" {
  subnet_id            = azurerm_subnet.tfaksvnet.id
  route_table_id       = azurerm_route_table.nattable.id
}

resource "azurerm_subnet" "tfjboxvnet" {
  name                 = "jbox-subnet"
  virtual_network_name = azurerm_virtual_network.tfvnet.name
  resource_group_name  = azurerm_resource_group.tfrg.name
  address_prefix       = "10.1.200.0/24"
}

# NSG
resource "azurerm_network_security_group" "tfaksnsg" {
  name                = "${var.prefix}-aksnsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.tag
  }
}

# UDR
resource "azurerm_route_table" "nattable" {
  name                = "${var.prefix}-natroutetable"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  
  route {
    name                   = "natrule1"
    address_prefix         = "10.100.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.10.1.1"
  }
}
resource "azurerm_kubernetes_cluster" "tfaks" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.tfrg.name
  dns_prefix          = "${var.prefix}dns"

  #kubernetes_version = "1.13.11"

  default_node_pool {
    name            = "default"
    node_count      = 2
    min_count       = 2
    max_count       = 3
    vm_size         = "Standard_DS1_v2"

    #os_type         = "Linux"
    os_disk_size_gb = 128

    # Autoscale
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true

    # AZ
    availability_zones = [1, 2]

    vnet_subnet_id = azurerm_subnet.tfaksvnet.id
  }

  linux_profile {
    admin_username = var.admin_username
    ssh_key {
      key_data = var.admin_keydata
    }
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  tags = {
    environment = var.tag
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "tfgpupool" {
    name            = "gpu"
    kubernetes_cluster_id = azurerm_kubernetes_cluster.tfaks.id
    node_count      = 1
    min_count       = 1
    max_count       = 2
    vm_size         = "Standard_DS1_v2" #"Standard_NC6"
    os_type         = "Linux"
    os_disk_size_gb = 128

    # Autoscale
    enable_auto_scaling = true

    vnet_subnet_id = azurerm_subnet.tfaksvnet.id
}

data "azurerm_public_ip" "example" {
  name                = reverse(split("/", tolist(azurerm_kubernetes_cluster.example.network_profile.0.load_balancer_profile.0.effective_outbound_ips)[0]))[0]
  resource_group_name = azurerm_kubernetes_cluster.example.node_resource_group
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.tfaks.kube_config[0].client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.tfaks.kube_config_raw
}

output "cluster_egress_ip" {
  value = data.azurerm_public_ip.example.ip_address
}

resource "azurerm_container_registry" "example" {
  name                = "${var.prefix}registry"
  resource_group_name = "${azurerm_resource_group.example.name}"
  location            = "${azurerm_resource_group.example.location}"
  sku                 = "Standard"
}

output "login_server" {
  value = "${azurerm_container_registry.example.login_server}"
}