// Create a Network Security Group
module nsg 'avm/res/network/networksecuritygroup:1.0.0' = {
  name: 'myNsg'
  params: {
    name: 'my-nsg'
    location: resourceGroup().location

    // Define security rules
    securityRules: [
      {
        name: 'Allow-HTTP'
        priority: 1000
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '80'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Allow-HTTPS'
        priority: 2000
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
      }
      {
        name: 'Deny-All-Inbound'
        priority: 4096
        direction: 'Inbound'
        access: 'Deny'
        protocol: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
      }
    ]
  }
}