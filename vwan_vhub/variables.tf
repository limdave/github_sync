variable "location" {
    description = "Location of the network"
    default     = "eastus"
}

variable "username" {
    description = "Username for Virtual Machines"
    default     = "azureuser"
}

variable "password" {
    description = "Password for Virtual Machines"
    default = "Pa55w.rd"
}

variable "vmsize" {
    description = "Size of the VMs"
    default     = "Standard_D2ds_v5"    #D2s_v3
}

variable "tags" {
  description = "Set of tags for resources"
  type        = map(string)
  default = {
    environment = "vwan-demo"
    deployment  = "terraform"
    owner       = "gslim"
  }
}