#이 문서에서는 Azure Resource Manager로 실행 중인 단일 서브넷 내 Azure Virtual Machines에서 SQL Server Always On 가용성 그룹에 대한 부하 분산 장치를 만드는 방법을 설명합니다. 
#SQL Server 인스턴스가 Azure Virtual Machines에 있는 경우 가용성 그룹을 사용하려면 부하 분산 장치가 필요합니다. 
#Azure 가상 네트워크 내의 여러 서브넷에 만들면 AG(Always On 가용성 그룹)에 대한 Azure Load Balancer가 필요하지 않습니다.
#https://blog.pythian.com/sql-server-distributed-availability-group-with-forwarder-in-microsoft-azure/

#Create the SQL Load Balencer
resource "azurerm_lb" "sqlLB" {
  name                = "lb-sqlha"
  location            = azurerm_resource_group.ggResourcegroup.location
  resource_group_name = azurerm_resource_group.ggResourcegroup.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                          = "lb-sqlha-ip"
    private_ip_address_allocation = "Static"
    #private_ip_address            = "${var.sqlServerConfig.sqlLBIPAddress}"
    private_ip_address            = "10.20.1.80"  #10.20.1.64/26
    subnet_id                     = azurerm_subnet.ggSubnet01.id
  }

}

#Create the load balencer backend pool
resource "azurerm_lb_backend_address_pool" "sqlLBBEP" {
  #resource_group_name = azurerm_resource_group.ggResourcegroup.name
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                = "sqlLB-bep"
}

#Add the VM to the load balencer
resource "azurerm_network_interface_backend_address_pool_association" "sqlvmBEAssoc" {
  count = var.instances_num
  network_interface_id    = azurerm_network_interface.vm_nic[count.index].id
  ip_configuration_name   = "VM-sql${count.index}-IP"
  backend_address_pool_id = azurerm_lb_backend_address_pool.sqlLBBEP.id
}


#Create the load balencer rules
resource "azurerm_lb_rule" "sqlLBRule" {
  #resource_group_name            = azurerm_resource_group.ggResourcegroup.name
  loadbalancer_id                = "${azurerm_lb.sqlLB.id}"
  name                           = "lb-sqlha-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = "lb-sqlha-ip"
  probe_id                       = "${azurerm_lb_probe.sqlLBProbe.id}"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.sqlLBBEP.id]
  #enable_floating_ip             = true
}

resource "azurerm_lb_rule" "sqlLBHAEndpointRule" {
  #resource_group_name            = azurerm_resource_group.ggResourcegroup.name
  loadbalancer_id                = "${azurerm_lb.sqlLB.id}"
  name                           = "lb-sqlha-hadr-endpoint-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 5022
  backend_port                   = 5022
  frontend_ip_configuration_name = "lb-sqlha-ip"
  probe_id                       = "${azurerm_lb_probe.sqlLBProbe.id}"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.sqlLBBEP.id]
  #enable_floating_ip             = true
}

#Create a health probe for the load balencer
resource "azurerm_lb_probe" "sqlLBProbe" {
  #resource_group_name = azurerm_resource_group.ggResourcegroup.name
  loadbalancer_id     = "${azurerm_lb.sqlLB.id}"
  name                = "lb-sqlha-SQLAOProbe"
  port                = 59999
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}
