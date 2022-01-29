## This code demonstrate how to setup Azure Redis Cache monitors
variable "cache" {
	description = "The Azure Redis Cache alerts"

	default = {
      		cache_name              = "<replace this with cache name>"
      		service_name			= "<replace this project name>"
      		environment				= "<Stage/Production>"
			scope                   = "/subscriptions/<subscription_id>/resourceGroups/<resource_group_name>/providers/Microsoft.Cache/Redis/<azure_redis_cache_name>"
			cache_hit_threshold     = 5000
			cache_misses_threshold  = 5000
			cache_cpu_threshold     = 50
			cache_connected_clients_threshold       = 5000
		
    }

}

#============================================================================
provider "azurerm" {
  version = "=2.0.0"
  features {}
}

resource "azurerm_monitor_action_group" "main" {
  name                = "example-actiongroup"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "exampleact"

  email_receiver {
    name                    = "ishantdevops"
    email_address           = "devops@example.com"
    use_common_alert_schema = true
  }

  webhook_receiver {
    name        = "callmyapi"
    service_uri = "http://example.com/alert"
  }
}


### Cache Hits Alert
resource "azurerm_monitor_metric_alert" "cache_hit_alert" {
  name                = "${var.cache.service_name} ${var.cache.environment} - Cache Hits Alert"
  resource_group_name = var.cache.cache_name
  scopes              = [var.cache.scope]
  description         = "${var.cache.service_name} Cache Hits Alert"

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "cachehits"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.cache.cache_hit_threshold

    
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}


### Cache Misses Alert
resource "azurerm_monitor_metric_alert" "cache_miss_alert" {
  name                = "${var.cache.service_name} ${var.cache.environment} - Cache Miss Alert"
  resource_group_name = var.cache.cache_name
  scopes              = [var.cache.scope]
  description         = "${var.cache.service_name} - Cache Miss Alert"

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "cachemisses"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.cache.cache_misses_threshold

    
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

### Cache Connection Alert
resource "azurerm_monitor_metric_alert" "cache_connected_clients" {
  name                = "${var.cache.service_name} ${var.cache.environment} - Cache Connected Clients"
  resource_group_name = var.cache.cache_name
  scopes              = [var.cache.scope]
  description         = "${var.cache.service_name} - Cache Connected Clients"

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "connectedclients"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.cache.cache_connected_clients_threshold

    
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}


### Cache CPU Alert
resource "azurerm_monitor_metric_alert" "cache_cpu" {
  name                = "${var.cache.service_name} ${var.cache.environment} - Cache CPU"
  resource_group_name = var.cache.cache_name
  scopes              = [var.cache.scope]
  description         = "${var.cache.service_name} - Cache CPU"

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "percentProcessorTime"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.cache.cache_cpu_threshold

    
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

#==================Log Analytics for AKS==============================

resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-k8s-resources"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = "${var.prefix}-law"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "example" {
  solution_name         = "Containers"
  workspace_resource_id = azurerm_log_analytics_workspace.example.id
  workspace_name        = azurerm_log_analytics_workspace.example.name
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Containers"
  }
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "${var.prefix}-k8s"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "${var.prefix}-k8s"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
    }
  }
}