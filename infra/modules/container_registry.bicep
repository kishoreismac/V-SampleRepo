@description('Container Registry name')
param acrName string
@description('Location for the Container Registry')
param location string 

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
