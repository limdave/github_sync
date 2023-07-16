# azure load balancer and backend pool
# Availability Zones are only supported with a Standard SKU and in select regions at this time.


# Public LB
resource "azurerm_public_ip" "azlb" {
  name                = "azlb-pip"
  location            = var.location
  #resource_group_name = var.resource_group_name azurerm_resource_group.ggResourcegroup.name
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  allocation_method   = "Static"

  sku                 = "Standard"
  tags = var.default_tags
}

# The SKU of the Azure Load Balancer. Accepted values are Basic, Standard and Gateway. Defaults to Basic.
resource "azurerm_lb" "azlb" {
  name                = "azlb-lb"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "azlb-ipconfig"
    public_ip_address_id = azurerm_public_ip.azlb.id
    #private_ip_address = [10.10.10.10]
  }

  tags = var.default_tags
}

# When using this resource, the Load Balancer needs to have a FrontEnd IP Configuration Attached
resource "azurerm_lb_rule" "azlb" {
  #resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.azlb.id
  name                           = "azlb-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 80   # Port on which load balancer will receive requests
  backend_port                   = 80   # Port of application on the VM
  frontend_ip_configuration_name = "azlb-ipconfig"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.azlb.id]
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.azlb.id
}

resource "azurerm_lb_backend_address_pool" "azlb" {
  #resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.azlb.id
  name                = "azlb-bepool"
}

# Backend Addresses can only be added to a Standard SKU Load Balancer.
resource "azurerm_lb_backend_address_pool_address" "azlbaddr" {
  count     = 2
  name                    = "azlb-bp-addr${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.azlb.id
  virtual_network_id      = azurerm_virtual_network.ggVnet01.id
  ip_address              = azurerm_linux_virtual_machine.gglinuxVM[count.index].private_ip_address
  depends_on              = [ azurerm_linux_virtual_machine.gglinuxVM ]
}

#vm : use the azurerm_lb_nat_rule resource.  #vmss : use the azurerm_lb_nat_pool resource.
/*
resource "azurerm_lb_nat_rule" "azlb" {
  count = 2
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.azlb.id
  name                           = "SSHvm${count.index}"    #실제 VM으로 매핑이 안됨
  protocol                       = "Tcp"
  frontend_port                  = "220${count.index + 1}"
  backend_port                   = 22
  backend_address_pool_id        = azurerm_lb_backend_address_pool.azlb.id
  frontend_ip_configuration_name = "azlb-ipconfig"
}
*/
resource "azurerm_lb_nat_rule" "azlbnat" {
  #count = 2
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.azlb.id
  name                           = "SSHvmnat"
  protocol                       = "Tcp"
  frontend_port_start            = 2201
  frontend_port_end              = 2203  #연결할 VM 수만큼 포트번호를 지정하여야 한다
  backend_port                   = 22
  backend_address_pool_id        = azurerm_lb_backend_address_pool.azlb.id
  frontend_ip_configuration_name = "azlb-ipconfig"
}

resource "azurerm_lb_probe" "azlb" {
  #resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.azlb.id
  name                = "healthprobe"
  protocol            = "Http"     #Tcp
  port                = 80
  request_path        = "/"
}


output "azlb_ip_address" {
  description = "Public IP address of the load balancer"
  value = azurerm_public_ip.azlb.ip_address
}