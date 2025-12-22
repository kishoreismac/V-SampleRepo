targetScope = 'resourceGroup'

@description('Name of the Key Vault in this resource group')
param keyVaultName string

@description('Principal ID (objectId) of the identity that needs KV permissions (project workspace managed identity)')
param principalId string

// Built-in Key Vault Secrets Officer role (tenant-wide, stable GUID)
resource kvSecretsOfficerRoleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  scope: subscription()
}

// Actual Key Vault resource to scope the assignment to
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource kvSecretsOfficerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, kvSecretsOfficerRoleDef.id, principalId)
  scope: kv
  properties: {
    roleDefinitionId: kvSecretsOfficerRoleDef.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output kvroleAssignmentId string = kvSecretsOfficerAssignment.id
