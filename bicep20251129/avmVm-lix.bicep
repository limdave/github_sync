targetScope = 'resourceGroup'

@description('Admin username for the VM')
param adminUsername string = 'ggadmin'

@secure()
@description('Admin password for the VM')
param adminPassword string

@description('Location for resources')
param location string = resourceGroup().location

@description('VM name')
param vmName string = 'vm-01ubuntu2404vm'

@description('Size of the VM')
param vmSize string = 'Standard_B2s'

@description('Ubuntu 24.04 LTS image reference')
param ubuntu2404Image object = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-noble'
  sku: '24_04-lts'
  version: 'latest'
}

module vnet 'avm/res/network/virtualnetwork:1.0.0' = {
  name: '${vmName}-VnetDeployment'
  params: {
    name: 'vnet-worker01'
    location: resourceGroup().location
    addressSpace: [
      '10.31.0.0/16'
    ]
    subnets: [
      {
        name: 'subnet-wk-frontend'
        addressPrefix: '10.31.1.0/24'
      }
    ]
    subnets: [
      {
        name: 'subnet-wk-backend'
        addressPrefix: '10.31.2.0/24'
      }
    ]
  }
}

module nic 'avm/res/network/networkinterface:1.0.0' = {
  name: '${vmName}-NicDeployment'
  params: {
    name: '${vmName}-nic'
    location: resourceGroup().location
    ipConfigurations: [
      {
        name: 'ipconfig1'
        privateIPAllocationMethod: 'Dynamic'
        subnetResourceId: vnet.outputs.subnets[0].id
      }
    ]
  }
}


module linuxVm 'br/public:avm/res/compute/virtualmachine:1.0.0' = {
  name: '${vmName}-module'
  params: {
    name: vmName
    location: resourceGroup().location
    osType: 'Linux'
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    imageReference: ubuntu2404Image
    networkInterfaces: [
      {
        name: '${vmName}-nic'
        ipConfigurations: [
          {
            name: 'ipconfig1'
            //subnetId: '/subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.Network/virtualNetworks/<vnetName>/subnets/<subnetName>'
            subnetId: vnet.outputs.subnets[0].id
            publicIpAddress: {
              name: '${vmName}-pip'
            }
          }
        ]
      }
    ]
  }
}


//deployment
//az deployment group create --resource-group <rgName> --template-file main.bicep
