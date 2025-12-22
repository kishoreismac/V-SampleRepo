@description('Name of the storage account')
param storageName string
@description('Location for the storage account')
param location string
@description('Resource tags.')
param tags object
@description('SKU for the storage account')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS', 'Premium_ZRS'])
param storageSkuName string = 'Standard_LRS'
@description('Access tier for the storage account')
@allowed(['Hot', 'Cool', 'Premium'])
param accessTier string = 'Hot'
@description('Allow public access to blobs in the storage account')
@allowed([true, false])
param allowBlobPublicAccess bool = false
@description('Allow cross-tenant replication for the storage account')
@allowed([true, false])
param allowCrossTenantReplication bool = false
@description('Allow shared key access for the storage account')
@allowed([true, false])
param allowSharedKeyAccess bool = false
@description('Minimum TLS version for the storage account')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'
@description('Default action for network ACLs on the storage account')
@allowed(['Allow', 'Deny'])
param storageNetworkAclsDefaultAction string = 'Deny'
@description('Array of containers to create.')
param containerNames array
@description('Create containers.')
param createContainers bool = true

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'

  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    publicNetworkAccess: 'Disabled'
    allowSharedKeyAccess: allowSharedKeyAccess
    minimumTlsVersion: minimumTlsVersion
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: storageNetworkAclsDefaultAction
      virtualNetworkRules: []
    }
  }
}

// Define blobService separately and link it to the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: storageAccount
  name: 'default'
}

// Define containers separately and link them to the blob service
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = [
  for containerName in containerNames: if (createContainers) {
    name: '${storageAccount.name}/default/${containerName}'
    properties: {
      publicAccess: 'None'
    }
  }
]

output storageAccountId string = storageAccount.id
output storageEndpoint string = storageAccount.properties.primaryEndpoints.blob
output storageContainer string = containerNames[0]
