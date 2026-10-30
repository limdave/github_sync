// Create a ADLS Gen2 Storage and Create Private endpoint using avm
// 2025.11.29. limgong.

/*
// Create a Storage Account with hierarchical namespace (Data Lake Gen2)
module storage 'avm/res/storage/storageaccount:1.0.0' = {
  name: 'myDataLakeStorage'
  params: {
    name: 'mystorageacctdl'
    location: resourceGroup().location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    enableHierarchicalNamespace: true
    // optional: configure networking, identity, etc.
  }
}

// Create a Private Endpoint for the Storage Account
module pe 'avm/res/network/privateendpoint:1.0.0' = {
  name: 'myPrivateEndpoint'
  params: {
    name: 'my-pe-datalake'
    location: resourceGroup().location
    subnetResourceId: resourceId(
      'Microsoft.Network/virtualNetworks/subnets',
      'my-vnet',
      'my-subnet'
    )
    privateLinkServiceConnections: [
      {
        name: 'storage-pls'
        privateLinkServiceId: storage.outputs.resourceId
        groupIds: [
          'blob' // for Data Lake Gen2, use blob endpoint
        ]
      }
    ]
  }
}
*/

// 1. Virtual Network + Subnet (needed for Private Endpoint)
module vnet 'br/public:avm/res/network/virtualnetwork:1.0.0' = {
  name: 'myVnet'
  params: {
    name: 'my-vnet'
    location: resourceGroup().location
    addressSpace: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: 'my-subnet'
        addressPrefix: '10.0.1.0/24'
      }
    ]
  }
}

// 2. Private DNS Zone for blob endpoint
module dnsZone 'br/public:avm/res/network/privatednszone:1.0.0' = {
  name: 'myBlobDnsZone'
  params: {
    name: 'privatelink.blob.core.windows.net'
    location: 'global'
  }
}

// 3. Link DNS Zone to VNet
module dnsLink 'br/public:avm/res/network/privatednszone/virtualnetworklink:1.0.0' = {
  name: 'myDnsLink'
  params: { 

     
     
    name: 'myDnsLink'
    location: 'global'
    privateDnsZoneId: dnsZone.outputs.resourceId
    virtualNetworkId: vnet.outputs.resourceId
    registrationEnabled: false
  }
}

// 4. Private DNS Zone Group (created before Storage Account)
module dnsGroup 'br/public:avm/res/network/privateendpoint/privateDnsZoneGroup:1.0.0' = {
  name: 'myDnsGroup'
  params: {
    name: 'myDnsZoneGroup'
    privateDnsZoneIds: [
      dnsZone.outputs.resourceId
    ]
  }
}

// 5. Storage Account with hierarchical namespace (Data Lake Gen2)
module storage 'br/public:avm/res/storage/storageaccount:1.0.0' = {
  name: 'myDataLakeStorage'
  params: {
    name: 'mystorageacctdl'
    location: resourceGroup().location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    enableHierarchicalNamespace: true
    blobServiceProperties: {
      deleteRetentionPolicy: {
        enabled: true
        days: 14
      }
      containerDeleteRetentionPolicy: {
      enabled: true
      days: 14
      }
      isVersioningEnabled: false  //true
    }
  }
}

// 6. Private Endpoint for Storage Account, referencing the DNS Group
module pe 'br/public:avm/res/network/privateendpoint:1.0.0' = {
  name: 'myPrivateEndpoint'
  params: {
    name: 'my-pe-datalake'
    location: resourceGroup().location
    subnetResourceId: vnet.outputs.subnets[0].id
    privateLinkServiceConnections: [
      {
        name: 'storage-pls'
        privateLinkServiceId: storage.outputs.resourceId
        groupIds: [
          'blob'
        ]
      }
    ]
    privateDnsZoneGroup: dnsGroup.outputs.resourceId
  }
}