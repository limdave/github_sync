# CNI Network # Example: Kubernetes Cluster using a Calico Networking Policy
# https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples/kubernetes
# https://pradeeploganathan.com/azure/building-a-secure-and-high-performance-aks-kubernetes-cluster-using-terraform/
# Upgrading your cluster may take up to 10 minutes per node.
# terraform으로 리소스 생성후 재실행(apply)할 경우, 기존 리소스를 삭제하고 재생성하도록 되어 있음으로 운영시에는 lifecycle 옵션을 이용할 것.
#--------------------------------------------------
# 2022.01.26 docs :  서비스 주체를 사용하는 경우, 귀하가 하나를 제공하거나 AKS가 귀하를 대신하여 하나를 생성해야 합니다. 관리 ID를 사용하는 경우 AKS에서 자동으로 생성됩니다.
#                    서비스 주체를 관리하면 복잡성이 추가되므로 관리 ID를 대신 사용하는 것이 더 쉽습니다. 
#-------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"     #2022.02.05기준 v2.95.0
    }
    azuread = {
      source = "hashicorp/azuread"
      version = "~>2.0"      #2021.12.22기준 v2.13  / 20220205 : v2.17.0
    }
  }
  backend "azurerm" {                 #협업 및 백업용도로 backend 사용함, storage와 container를 먼저 생성후에 Terraform code를 작성한다.
    resource_group_name = "cloud-shell-storage-southeastasia"
    storage_account_name = "csXXXX3200094ea6d93"    #XXX-MPN cloudshell storage
    container_name = "tfstate"
    key = "terraform.tfstate"
  } 
}

provider "azurerm" {
  features {}
}

provider "azuread" {
  features {}
  #tenant_id = "6144959d-XXXX-4d3d-9090-c4891f1914ce"    #XXX_MPN tenant
}

data "azuread_client_config" "current" {}

# Create Azure AD Group in Active Directory for AKS Admins
resource "azuread_group" "aks_admin" {
  #name        = "${azurerm_resource_group.aks_rg.name}-cluster-admin"
  display_name = "aksadmingp"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
  description = "Azure AKS Kubernetes administrators for the ${azurerm_resource_group.aks_rg.name}-cluster."
}

# Create a resource group / you have tp change the name and location
resource "azurerm_resource_group" "aks_rg" {
  name     = "${var.resource_group_name}-${formatdate("YYYYMMDD",timestamp())}"
  location = var.location
  tags = {
    created = "${timeadd(timestamp(),"9h")}"
    owneer  = "gslim"
  }
}

# Create a log monitor for container log
resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "aks_insights" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = azurerm_resource_group.aks_rg.location
    resource_group_name = azurerm_resource_group.aks_rg.name
    retention_in_days   = 30              #free = 7days
    sku                 = "PerGB2018"     #free = daily_quota_gb is 0.5GB

    #lifecycle {
    #    ignore_changes = [
    #        name,
    #    ]
    #}
}

resource "azurerm_log_analytics_solution" "aks_logs" {      #이건 뭐지?
    solution_name         = "ContainerInsights"
    location              = var.location
    resource_group_name   = azurerm_resource_group.aks_rg.name
    workspace_resource_id = azurerm_log_analytics_workspace.aks_insights.id
    workspace_name        = azurerm_log_analytics_workspace.aks_insights.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
    tags = {
      created = "${timeadd(timestamp(),"9h")}"
    }
}

# create a virtual network
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "${var.prefix}-network"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = ["10.1.0.0/16"]
  tags = {
    created = "${timeadd(timestamp(),"9h")}"
  }
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "internalsub"
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  resource_group_name  = azurerm_resource_group.aks_rg.name
  address_prefixes     = ["10.1.0.0/22"]
}

#create a kubernetes cluster with CNI
resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${var.prefix}-k8scni"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "${var.prefix}-k8s"     #3~45문자
  #dns_prefix_private_cluster = ???
  #kubernetes_version              = var.kubernetes_version  #미정의시 권장되는 최신버전으로 자동 지정
  #api_server_authorized_ip_ranges = ???
  private_cluster_enabled         = false  

  default_node_pool {
    name           = "systempool"
    node_count     = 2
    vm_size        = "Standard_D2s_v4"
    type           = "VirtualMachineScaleSets"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    #max_pods  = 250
    #node_labels = {"environment" = "prod"}
    #enabled_auto_scaling = false   #default = false, true이면 aks auto scaler 활성화
    #min_count = 1
    #max_count = 5
    #node_taints = ["CriticalAddonsOnly=true:NoSchedule"]
  }

  network_profile {                   #이 block이 없으면 기본적으로 kubenet으로 설정됨
    network_plugin    = "azure"
    network_policy    = "calico"      #Azure or Calico
    load_balancer_sku = "standard"
    #service_cidr = ["10.100.0.0/16"]     #Vnet에 있지 않아야 함. 비어 있거나 설정되어야 함
    #dns_service_ip = "10.100.0.10"                #비어 있거나 설정되어야 함
    #docker_bridge_cidr = ["172.17.0.1/16"]        #비어 있거나 설정되어야 함
    #outbound_type = "userDefinedRouting"       #default=loadBalancer  / UDR지정시 라우팅테이블을 지정해야 함
  }

  identity {
    type = "SystemAssigned"   #system assigned or Service Principal
  }
  #service_principal {
    #    client_id     = var.client_id
    #    client_secret = var.client_secret
  #}

  role_based_access_control {
    enabled = true
    azure_active_directory {   #provider "azuread" 항목이 추가 되어야 할 듯.
      managed = true          #Azure Active Directory 통합이 관리됩니다.
      admin_group_object_ids = [azuread_group.aks_admin.id]
      }
  }

  linux_profile {
    admin_username = "ggadm"
    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  #private_cluster_enabled = true   #private cluster 생성시 사용
  addon_profile {
    aci_connector_linux {
      enabled = false     #가상노드 사용시
    }

    azure_policy {
      enabled = false     #승인컨트롤러 webhook인 Gatekeeper 적용시(K8s 버전1.14이상, Linux노드만)
    }

    http_application_routing {
      enabled = false        #ingress 적용시 true
    }

    oms_agent {
      #enabled = false     #Container Insights 설정시, Log Analytics workspace가 있어야 함
      enabled = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_insights.id
    }


    #ingress_application_gateway {
    #  enabled = true           #AGIC포드 생성은 별도 구성
    #  gateway_id = ??
    #  gateway_name = ??
    #  subnet_cidr = ??
    #  subnet_id = ??
    #}
  }
  
  tags = {
    created = "${timeadd(timestamp(),"9h")}"
  }
}

resource "local_file" "kubeconfig" {
  depends_on   = [azurerm_kubernetes_cluster.k8s]
  filename     = "kubeconfig"
  content      = azurerm_kubernetes_cluster.k8s.kube_config_raw
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {    #aks의 별도의 user node pool 생성시 사용
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s.id
  vm_size               = "Standard_D2s_v5"
  node_count            = 2
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  #od_type               = "Linux"
  #enable_auto_scaling   = true
}

/*
# 노드풀에 대한 변경 적용시
resource "azurerm_kubernetes_cluster_node_pool" "mem" {
 kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
 name                  = "mem"
 node_count            = "1"
 vm_size               = "standard_d11_v2"
}

# UDR인 경우 라우팅 설정
resource "azurerm_route_table" "aks_route_table" {
  name                = "${azurerm_resource_group.aks_res_grp.name}-routetable"
  location            = azurerm_resource_group.aks_res_grp.location
  resource_group_name = azurerm_resource_group.aks_res_grp.name

  route {
    name                   = "cluster-01"
    address_prefix         = ["10.100.0.0/16"]
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.10.1.1"
  }

  route {
        name           = "default-route"
        address_prefix = "0.0.0.0/0"
        next_hop_type  = "VirtualNetworkGateway"   #???
  }
}
resource "azurerm_subnet_route_table_association" "cluster-01" {
  subnet_id      = azurerm_subnet.aks_subnet.id
  route_table_id = azurerm_route_table.aks_route_table.id
}
*/