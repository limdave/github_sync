#Typical uses for the hub and spoke architecture with Virtual WAN
# vWAN + vHub + secured hub with Firewall
# 보안허브는 firewall-manager를 이용해서 생성해야 한다. 현재 Terraform code로는 바로 보안허브를 생성할 수 없다.
# 본 데모 환경은 2개의 spoke-vnet과 on-prem 그리고 branch로 구성된 각각의 네트워크를 연결하는 데모 코드이다.
#=========================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.91"   #"">=2.90"  "~>2.0"
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