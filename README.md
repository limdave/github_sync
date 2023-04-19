# github_sync
### Readme : This is a Terraform files repository that azure resource create.
Azure를 위한 Terraform File입니다. 작성시작일자 : 2022.01.31

* azurerm 버전 : v2.93 이후
* azuread 버전 : 미사용
* terraform 버전 : v1.0.10 이후 로 테스트된 것입니다.

제가 사용하려고 만든 것이라 범용적이지 않지만, 기본적인 형태임으로 쉽게 변경하여 사용할 수 있습니다.
모듈화하지 않고 바로바로 해당되는 리소스를 만들기 위한 용도로 작성한 파일입니다.

다수의 사용자와 같이 사용하거나 대규모를 위한 인프라 구성은 좀 더 고민을 많이하고 사용하여야 할것입니다.

## AKS_CNI
이 폴더의 terraform code는 추가적인 테스트가 필요하다. 특히 azuread에 대한 체크가 필요합니다.
최근에 aks의 인증방식이 service principal에서 managed ID로 변경된 것으로 추정한다.

## 2022.08.19
key vault 와 ag_waf 소스를 업데이트 함.
최근에 접근권한으로 managed-id를 사용하는 방식으로 변경되어 사용자계정과 무관하여 리소스의 접근권한을 부여하도록 되어 있다.
waf의 경우에도 FW처럼 별도의 policy 리소스를 생성하여 관리하는 방식으로 변경된 듯하다.

## 2023.04.17
IaaS기반의 SQL AlwaysOn Availability Group를 위한 ADDC용 VM과 MSSQL VM을 생성하는 코드를 생성했다.
MSSQL은 SQL2019-Windows2019의 이미지를 이용하여 Data 및 Log 디스크가 생성되도록 했다. (이 부분이 제일 어려워 많은 날을 여기에 소비했다)
실제 AOAG구성을 위해서는 DC구성하고 컴퓨터객체 및 계정(설치)을 생성하여 구성하는 지난한 과정이 필요하다.
사전준비로 Failover Cluster 객체명과 AOAG 객체명, 그리고 단일 서브넷을 위한 LB연동 목적의 AOAG Listener 객체명이 준비되면 혼선이 적겠다. 