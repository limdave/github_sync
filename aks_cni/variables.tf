# *.tfvars 파일이 있으면 variables.tf보다 먼저 적용된다.?? by limgongsik. 2021.12.20 
# 
# variables
variable "prefix" {
  description = "A prefix used for all resources in this example"
  default     = "calico"
}

variable "agent_count" {
    default = 3
}

variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}

variable "dns_prefix" {
    default = "k8stest"
}

variable cluster_name {
    default = "k8stest"
}

variable resource_group_name {
    description = "Name of the resource group."
    default = "rg-k8stest"
}

variable location {
    description = "Location of the azure resources."
    default = "East US"
}

variable log_analytics_workspace_name {
    default = "aksLogAnalWorkspaceName"
}

# refer https://azure.microsoft.com/global-infrastructure/services/?products=monitor for log analytics available regions
variable log_analytics_workspace_location {
    default = "eastus"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing 
variable log_analytics_workspace_sku {
    default = "PerGB2018"
}

#tfstat 상태 저장용. cloud shell용 스토리지 사용.
variable "storage_account_name" {
    description = "Name of storage account"
    default = "cs11003200094ea6d93"
}
/*
variable "aad_group_name" {
  description = "Name of the Azure AD group for cluster-admin access"
  type        = string
  default = "aksadmingp"
}
*/
/*
variable "k8s_version_prefix" {
  description = "Minor Version of Kubernetes to target (ex: 1.20)"
  type        = string
  default     = "1.20"
}

variable "tags" {
  type        = map
  default     = {
    created = "${timeadd(timestamp(),"9h")}"
  }
  description = "Set of base tags that will be associated with each supported resource."
}
*/

