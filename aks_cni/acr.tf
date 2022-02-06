#ACR : Azure Container Registry
#Reference : https://gaunacode.com/azure-container-registry-and-aks-with-terraform
# This is a terraform example for (Attaching a Container Registry to a Kubernetes Cluster)

resource "azurerm_container_registry" "ggacr" {
  name                = "aksggacr1"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  sku                 = "Standard"       #Possible values are Basic, Standard and Premium
  admin_enabled       = false
  #public_network_access_enabled = false #default = true
  #regional_endpoint_enabled = false    #default
}

resource "azurerm_role_assignment" "acrpull_role" {
  principal_id                     = azurerm_kubernetes_cluster.k8s.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.ggacr.id
  skip_service_principal_aad_check = true
}

/* 
# This is geo-replication example
resource "azurerm_container_registry" "acr" {
  name                = "containerRegistry1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = false
  georeplications {
    location                = "East US"
    zone_redundancy_enabled = true
    tags                    = {}
  }
  georeplications {
    location                = "westeurope"
    zone_redundancy_enabled = true
    tags                    = {}
  }
}

#============================
# This is encryption example
#===============================
resource "azurerm_container_registry" "acr" {
  name                = "containerRegistry1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.example.id
    ]
  }

  encryption {
    enabled            = true
    key_vault_key_id   = data.azurerm_key_vault_key.example.id
    identity_client_id = azurerm_user_assigned_identity.example.client_id
  }

}

resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  name = "registry-uai"
}

data "azurerm_key_vault_key" "example" {
  name         = "super-secret"
  key_vault_id = data.azurerm_key_vault.existing.id
}
*/