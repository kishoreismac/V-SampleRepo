targetScope = 'resourceGroup'

@description('Name of the User Assigned Managed Identity')
param uamiName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  location: resourceGroup().location

  name: uamiName
}

output uamiPrincipalId string = uami.properties.principalId
output uamiID string = uami.id
output uamiClientId string = uami.properties.clientId
