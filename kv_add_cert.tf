#this is a test for deploy key vault and secret, self-signed certificate
#2022.08.19

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 3.15.0"
    }
  }
    backend "local" {
    path = "./terraform.tfstate"
  }
} 

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}


# variables
variable "prefix" {
  description = "A prefix used for all resources in this example"
  default     = "EduEnroll"
}

variable "location" {
    description = "Location of the azure resources."
    default = "East US"
}

variable "default_tags" {
  description = "Set of base tags that will be associated with each supported resource."
  type        = map
  default     = {
    owner     = "gslim"
    created   = "2022.08.19 13:00"
  }
}

data "azurerm_client_config" "current" {}

# Create a resource group / you have to change the name and location
resource "azurerm_resource_group" "aks_rg" {
  name     = "kv-test-${formatdate("YYYYMMDD",timestamp())}"
  location = var.location
  tags = {
    created = "${timeadd(timestamp(),"9h")}"
    owner  = "gslim"
    purpose = "aks_kv"
  }
}


resource "azurerm_key_vault" "aks_kv" {
  name                = "${var.prefix}-demo-kv"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"   #Possible values are standard and premium. 소문자
  soft_delete_retention_days  = 7   #This value can be between 7 and 90 (the default) days.
  purge_protection_enabled = false  #Defaults to false
  #enabled_for_disk_encryption = true  
  #enabled_for_deployment = true
  #enable_rbac_authorization = true  <-- 관리ID를 사용할 때 disable(false)

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
    # One or more IP Addresses, or CIDR Blocks to access this Key Vault.
    #ip_rules                   = ["123.201.18.148"]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id    #user login id
    #application_id = ??

    certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Backup",
      "Purge",
      "Recover",
    ]

    key_permissions = [
      "List",
      "Create",
      "Delete",
      "Get",
      "Update",
      "Backup",
      "Purge",
      "Recover",     
    ]

    secret_permissions = [
      "Set",
      "Get",
      "List",
      "Delete",
      "Backup",
      "Purge",
      "Recover",
    ]
  }
/*
  # A notification is sent to all the specified contacts for any certificate event in the key vault. 
  # This field can only be set once user has `managecontacts` certificate permission.
  contact {
      email = "gslim@tdgl.co.kr"
      name  = "gslim"
      phone = "01012341234"
  }
*/
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    #object_id = data.azurerm_client_config.current.object_id
    object_id    = azurerm_user_assigned_identity.agw.principal_id   # managed-id를 사용하도록 설정하는 것임

    certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Backup",
      "Purge",
      "Recover",
    ]

    key_permissions = [
      "List",
      "Create",
      "Delete",
      "Get",
      "Update",
      "Backup",
      "Purge",
      "Recover",      
    ]

    secret_permissions = [
      "Set",
      "Get",
      "List",
      "Delete",
      "Backup",
      "Purge",
      "Recover",
    ]
  }

  tags = var.default_tags
}

/*
resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id = azurerm_key_vault.aks_kv.id
  tenant_id    = azurerm_client_config.current.tenant_id
  object_id    = azurerm_client_config.current.object_id

    certificate_permissions = [
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "SetIssuers",
      "Update",
      "Backup",
      "Purge",
      "Recover",
    ]

    key_permissions = [
      "List",
      "Create",
      "Delete",
      "Get",
      "Update",
      "Backup",
      "Purge",
      "Recover",      
    ]

    secret_permissions = [
      "Set",
      "Get",
      "List",
      "Delete",
      "Backup",
      "Purge",
      "Recover",
    ]
}
*/

resource "azurerm_key_vault_key" "aks_kvkey" {
  name         = "kv${var.prefix}key"
  key_vault_id = azurerm_key_vault.aks_kv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "wrapKey",
    "unwrapKey",
  ]
  tags = var.default_tags
}

resource "azurerm_key_vault_secret" "aks_kvsec" {
  name         = "kv${var.prefix}secret"
  value        = "limgong4Pass"
  key_vault_id = azurerm_key_vault.aks_kv.id
  depends_on   = [azurerm_key_vault.aks_kv]
  expiration_date = "2022-12-31T23:59:59Z"
  tags = var.default_tags
}

/*
#Provide certificate to import an existing certificate, certificate_policy to generate a new certificate.
resource "azurerm_key_vault_certificate" "aks_kvcert" {
  name         = "kvimported-cert"
  key_vault_id = azurerm_key_vault.aks_kv.id

  certificate {
    contents = filebase64("certificate-to-import.pfx")
    password = "aso!@#daeduck"
  }
  tags  = var.default_tags
  lifecycle {ignore_changes = [certificate]}
}
*/

#Example Usage (Generating a new certificate) :https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate
resource "azurerm_key_vault_certificate" "aks_kvcert" {
  name         = "${var.prefix}ggsite1-cert"
  key_vault_id = azurerm_key_vault.aks_kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"     #Possible values include Self (for self-signed certificate), or Unknown (for a certificate issuing authority like Let's Encrypt and Azure direct supported ones)
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"   # for a PFX 
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = ["gongsik.kr"]
      }

      subject            = "CN=gongsik.kr"
      validity_in_months = 12
    }
  }
  tags = var.default_tags
}

resource "azurerm_user_assigned_identity" "agw" {
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  name                = "uai-${var.prefix}_kv_agw_permission"
}

/*
# role_assignment가 없어도 리소스들 생성에 영향이 없었음
resource "azurerm_role_assignment" "key_vault_role" {
  scope                = azurerm_key_vault.aks_kv.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.agw.principal_id

  depends_on = [
    azurerm_key_vault.aks_kv, 
    azurerm_user_assigned_identity.agw, 
    azurerm_key_vault_certificate.aks_kvcert
  ]
}
*/

