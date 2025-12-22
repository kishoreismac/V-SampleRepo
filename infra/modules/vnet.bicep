@description('Location for the Virtual Network.')
param vnetLocation string
@description('The name of the virtual network')
param vnetName string

// @description('Existing (legacy) prefix to preserve during migration')
// param existingPrefix string = '210.210.0.0/16'

@description('New private prefix for compliant services')
param newPrefix string = '172.16.0.0/16'

@description('New agent subnet name')
param agentSubnetName string = 'Agent-Subnet-Private'
@description('New private endpoint subnet name')
param peSubnetName string = 'PE-Subnet'
@description('New VM subnet name (private)')
param vmSubnetName string = 'VM-Subnet-Private'

var agentSubnet = '172.16.0.0/24'
var peSubnet = '172.16.1.0/24'
var vmSubnet = '172.16.2.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: vnetLocation
  properties: {
    // IMPORTANT: include BOTH prefixes so ARM doesn't try to delete the old one
    addressSpace: {
      addressPrefixes: [
        newPrefix
      ]
    }
    // Do NOT include the old in-use "VM-Subnet" here.
    // Only add new subnets carved from 172.16.0.0/16.
    subnets: [
      {
        name: agentSubnetName
        properties: {
          addressPrefix: agentSubnet
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnet
        }
      }
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnet
        }
      }
    ]
  }
}

output agentSubnetId string = '${vnet.id}/subnets/${agentSubnetName}'
output peSubnetId string = '${vnet.id}/subnets/${peSubnetName}'
output vmSubnetId string = '${vnet.id}/subnets/${vmSubnetName}'
output peSubnetName string = peSubnetName
output agentSubnetName string = agentSubnetName
output virtualNetworkName string = vnet.name
output virtualNetworkId string = vnet.id
output virtualNetworkResourceGroup string = resourceGroup().name
output virtualNetworkSubscriptionId string = subscription().subscriptionId
