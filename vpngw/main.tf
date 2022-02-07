#Typical uses for the hub and spoke architecture
#This is a Terraform code for VPN connection between Cloud VPN Gateway and On-Prem Local Gateway 
#===========================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.90"   #">=2.90"  "~>2.0"
    }
  }
  #backend "azurerm" {
  #  resource_group_name  = "TerraformState_CloudShell"
  #  storage_account_name = "tfstatecloudshell2021"
  #  container_name       = "tfstate"
  #  key                  = "prod.terraform.tfstate"
  #}
}

provider "azurerm" {
  features {}
}