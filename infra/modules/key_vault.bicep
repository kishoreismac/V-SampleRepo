@description('Name of the Key Vault to create')
param keyVaultname string
@description('Location for the Key Vault')
param location string = resourceGroup().location
@description('Resource tags.')
param tags object
@description('SKU for the Key Vault')
@allowed(['standard', 'premium'])
param skuName string = 'standard'
@description('Tenant ID for the Key Vault')
param tenantId string = subscription().tenantId
@description('Network ACLs default action for the Key Vault')
@allowed(['Allow', 'Deny'])
param vaultNetworkAclsDefaultAction string = 'Allow'
@description('Enable deployment to the Key Vault')
param enabledForDeployment bool = true
@description('Enable disk encryption for the Key Vault')
param enabledForDiskEncryption bool = true
@description('Enable template deployment for the Key Vault')
param enabledForTemplateDeployment bool = true
@description('Enable purge protection for the Key Vault')
param enablePurgeProtection bool = false
@description('Enable RBAC authorization for the Key Vault')
param enableRbacAuthorization bool = true
@description('Enable soft delete for the Key Vault')
param enableSoftDelete bool = true
@description('Soft delete retention period in days for the Key Vault')
param softDeleteRetentionInDays int = 90

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultname
  location: location
  tags: tags
  properties: {
    createMode: 'default'
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: vaultNetworkAclsDefaultAction
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enablePurgeProtection: enablePurgeProtection ? enablePurgeProtection : null
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
