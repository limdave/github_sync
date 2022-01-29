# This a examples from "https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples"

variable "resource_group" {
  description = "The name of the resource group in which to create the virtual network."
  default = "rg-eus-test10"   
}

variable "location" {
  description = "The name of the location name in which to create the virtual network."
  default = "eastus"    #koreacentral, koreasouth
}

variable "default_tags" {
  description = "please define a tag name like date, role, environment and etc"
    type = map(string)
    default = {
        envrionment = "test"
        datetime = "2022.01.19 13:00",
        owner   = "gslim"
    }
}

variable "instances_num" {
  description = "Specify the number of vm instances."
  type        = number
  default     = 1
}

variable "hub_vnet" {
  description = "The Private IP range for Hub Vritual Network."
  default = ["10.10.0.0/16"]
}

variable "spoke1_vnet" {
  description = "The Private IP range for Spoke 01 Vritual Network."
  default = ["10.11.0.0/16"]
}

variable "admin_username" {
  description = "administrator name for created VM"
  default     = "ggadmin"
}

variable "admin_password" {
  description = "administrator password (recommended to disable password auth)"
  #default     = "1234!"
}

