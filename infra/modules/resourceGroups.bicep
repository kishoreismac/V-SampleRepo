targetScope = 'subscription'

@description('Name of the resource group')
param resourceGroupName string

@description('Location of the resource group')
param resourceGroupLocation string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: resourceGroupLocation
}

output resourceGroupNameOut string = rg.name
output resourceGroupLocationOut string = rg.location
