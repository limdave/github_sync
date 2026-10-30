#!/bin/bash
set -e

## This script deploys an AKS cluster with CNI networking and a Gateway API.
## 2026.10.30. limgong.

# 애플리케이션 라우팅 추가 기능 Kubernetes Gateway API 구현은 Istio 컨트롤 플레인을 배포하여 Kubernetes Gateway API 리소스에 대한 인프라를 관리합니다.
#1)애플리케이션 라우팅 게이트웨이 API :	게이트웨이 클래스 이름 -  approuting-istio
#2)Istio 서비스 메쉬 추가 기능	: 게이트웨이 클래스 이름 - istio  / asm-1-26 부 수정 버전 이상
### azure-cli 버전 2.86.0 이상을, AKS 1.36 이상(게이트웨이 API번들 버전: v1.5.1)을 실행하는 사용해야 합니다. 
### Managed Gateway API CRD(사용자 지정 리소스 정의) 설치를 사용하도록 설정합니다.

# 1. aks-preview 확장 설치
#az extension add --name aks-preview
#az provider register --namespace Microsoft.ContainerService

# 2. variables
OWNER=gslim
RG_NAME=rg-${OWNER}-20261030-01
CLUSTER_NAME=aksgg30cluster
LOCATION=koreacentral

# Create a resource group
az group create --name $RG_NAME --location $LOCATION --tags owner=$OWNER

# Create a virtual network and subnet
az network vnet create \
    --resource-group $RG_NAME \
    --name vnet-spoke01 \
    --address-prefixes 10.30.0.0/16 \
    --subnet-name sbnet-aksnode01 \
    --subnet-prefix 10.30.12.0/24 \
    --tags owner=$OWNER      

echo
echo "Resource group, virtual network, and subnet created successfully."
echo
# Get the virtual network subnet resource ID
SUBNET_ID=$(az network vnet subnet show --resource-group $RG_NAME --vnet-name vnet-spoke01 --name sbnet-aksnode01 --query id -o tsv)

#(참고: --pod-cidr을 별도로 지정하지 않으면 기본값으로 10.244.0.0/16이 할당됩니다. CNI모드에서는 --pod-cidr을 지정하는 것이 좋습니다.)
#--network-policy azure    <--- 네트워크 정책 적용(Azure 또는 Calico) cillium
#--ssh-access disabled 옵션은 AKS 노드 풀의 SSH 포트를 차단하여 외부 공격 표면(Attack Surface)을 줄이고 보안성을 높이는 권장 구성입니다.
az aks create \
    --resource-group $RG_NAME \
    --name $CLUSTER_NAME \
    --tier free \
    --location $LOCATION \
    --node-count 2 \
    --generate-ssh-keys \
    --service-cidr 172.16.0.0/16 \
    --dns-service-ip 172.16.0.10 \
    --vnet-subnet-id $SUBNET_ID \
    --vm-set-type VirtualMachineScaleSets \
    --node-vm-size Standard_D4s_v5 \
    --kubernetes-version 1.37.1 \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --enable-managed-identity \
    --network-policy azure \
    --enable-app-routing-istio \
    --enable-gateway-api \
    --tags owner=$OWNER    

echo
echo "AKS cluster created successfully."
echo
#별도의 노드풀을 생성하려는 경우(예: 윈도우서버)
# Windows 노드 풀(Agent Pool)의 이름은 최대 6자까지만 설정할 수 있습니다. (Linux 노드 풀은 최대 12자까지 가능)
az aks nodepool add \
    --resource-group $RG_NAME \
    --cluster-name $CLUSTER_NAME \
    --os-type Windows \
    --name winpl \
    --node-count 1

# Linux 노드 풀 추가 명령어 실행
az aks nodepool add \
    --resource-group $RG_NAME \
    --cluster-name $CLUSTER_NAME \
    --name userpool \
    --os-type Linux \
    --node-count 2 \
    --node-vm-size Standard_D4s_v5 \
    --vnet-subnet-id $SUBNET_ID \
    --mode User \
    --tags owner=$OWNER role=application

echo
echo "AKS Windows pool created successfully."
echo


az aks get-credentials --resource-group $RG_NAME --name $CLUSTER_NAME

exit 0

##=============================================================================================##
#아웃바운드 인터넷 통신(이미지 다운로드, 패치 등)을 지원하기 위해 NAT Gateway와 공용 IP를 생성
# 1. 사용할 변수 정의 (기존 환경에 맞게 매핑)
NATGW_NAME="natgw-aks-prod"
NATGW_PIP_NAME="pip-natgw-aks-prod"

# 2. NAT Gateway가 외부와 통신할 공용 IP 생성 (Standard SKU 필수)
az network public-ip create \
    --resource-group $RG_NAME \
    --name $NATGW_PIP_NAME \
    --location $LOCATION \
    --sku Standard \
    --allocation-method Static

# 3. NAT Gateway 리소스 생성 및 공용 IP 연결
az network nat gateway create \
    --resource-group $RG_NAME \
    --name $NATGW_NAME \
    --location $LOCATION \
    --public-ip-addresses $NATGW_PIP_NAME

# 4. 기존 AKS 노드용 서브넷에 NAT Gateway 바인딩 (이 시점부터 서브넷 아웃바운드가 NAT GW로 라우팅됨)
az network vnet subnet update \
    --resource-group $RG_NAME \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --nat-gateway $NATGW_NAME



## AKS 배포시 완전한 사설(Private) 클러스터로 구축하려면 두 가지 옵션이 추가되어야 합니다.
#    --enable-private-cluster : 사설 링크(Private Endpoint)로 숨겨 외부 노출을 차단.
#    --outbound-type userDefinedRouting : 트래픽은 사용자가 연결한 Azure Firewall이나 NAT Gateway 등의 라우팅 테이블을 강제로 따르게.
# NAT Gateway가 서브넷에 연결되었으므로, AKS를 생성할 때 아웃바운드 타입을 --outbound-type userAssignedNATGateway로 명시
az aks create \
    --resource-group $RG_NAME \
    --name $CLUSTER_NAME \
    --tier free \
    --location $LOCATION \
    --enable-private-cluster \
    --outbound-type userDefinedRouting \
    --node-count 2 \
    --generate-ssh-keys \
    --service-cidr 172.16.0.0/16 \
    --dns-service-ip 172.16.0.10 \
    --vnet-subnet-id $SUBNET_ID \
    --vm-set-type VirtualMachineScaleSets \
    --node-vm-size Standard_D4s_v5 \
    --kubernetes-version 1.37.1 \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --enable-managed-identity \
    --network-policy azure \
    --enable-app-routing-istio \
    --enable-gateway-api \
    --tags owner=$OWNER 

