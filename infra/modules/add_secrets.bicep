targetScope = 'resourceGroup'

@description('Name of the Key Vault (global DNS unique).')
param keyVaultName string // reuse your existing param

@secure()
@description('SQL admin password (ROTATED). Do NOT hardcode here; pass via parameters.')
param sqlAdminPassword string

@description('Administrator login for the SQL Server.')
param sqlAdminLogin string

@description('Name of the Azure Cognitive Search service')
param searchServiceName string

@description('Name of the Azure Cognitive Search service Index')
param searchIndexName string

@description('Name of the SQL Database.')
param sqlDatabaseName string

@secure()
@description('SerpAPI key. Do NOT hardcode.')
param serpApiKey string

@description('Name of the AI Hub (AML workspace)')
param hubName string

@description('Name of the Storage Account')
param storageAccountName string

@description('Name of the Storage Container')
param storageContainerName string

@description('Name of the Project (AML workspace)')
param projectName string

@description('Name of Azure AI Services account.')
param aiName string

@description('Name of Embedding Model.')
param embeddingModel string

@description('Name of the Model.')
param modelName string

@description('Optional: RG name of the AI Hub (AML workspace) if different from deployment RG.')
param rgName string

@description('Endpoint of the SQL Server')
param sqlServerURL string

@description('Service Principal (SP) Tenant ID')
param spTenantID string

@description('Service Principal (SP) Secret')
param spSecret string

@description('Client ID of the Service Principal (SP)')
param spClientID string

// ---- EXISTING AML WORKSPACE (AI Hub) TO GRAB ITS MANAGED IDENTITY ----
resource hub 'Microsoft.MachineLearningServices/workspaces@2025-06-01' existing = {
  name: hubName
  scope: resourceGroup(subscription().subscriptionId, rgName)
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// ---- RBAC: give AML workspace managed identity "Key Vault Secrets User" on this vault ----
// Role Definition ID for "Key Vault Secrets User"
var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource keyVaultReaderToAml 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, hub.id, 'keyVault-secrets-user-assignment')
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: hub.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---- SECRETS TO SEED ----
// Keep the names consistent with your app's expectations

resource secSqlPwd 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-sql-password'
  properties: {
    value: sqlAdminPassword
  }
}

resource secSerp 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'serp-api-key'
  properties: {
    value: serpApiKey
  }
}

resource secSqlSrv 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-sql-server'
  properties: {
    value: sqlServerURL
  }
}

resource secSqlDb 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-sql-database'
  properties: {
    value: sqlDatabaseName
  }
}

resource secSqlUser 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-sql-username'
  properties: {
    value: sqlAdminLogin
  }
}

resource secAoaiEndpoint 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-openai-endpoint'
  properties: {
    value: 'https://${aiName}.openai.azure.com/'
  }
}

resource secSearchEndpoint 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-search-endpoint'
  properties: {
    value: 'https://${searchServiceName}.search.windows.net'
  }
}

resource secEmbedDep 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-openai-embedding-deployment'
  properties: {
    value: embeddingModel
  }
}

resource secSearchIndex 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azureai-search-index-name'
  properties: {
    value: searchIndexName // if you have this as a param; otherwise use your 'medical-docs-index'
  }
}

// Optional: model deployment name for chat model
resource secChatModel 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'model-deployment-name'
  properties: {
    value: modelName
  }
}

resource subID 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'subscription-id'
  properties: {
    value: subscription().id
  }
}

resource AIName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'aiName'
  properties: {
    value: aiName
  }
}

resource RGName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'rgName'
  properties: {
    value: rgName
  }
}

var amlHost = '${resourceGroup().location}.api.azureml.ms'
var projectConnString = '${amlHost};${subscription().subscriptionId};${rgName};${projectName}'

var storageConnString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

resource AIProjectConnStrg 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ai-project-conn-string'
  properties: {
    value: projectConnString
  }
}

resource StorageProjectConnStrg 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-conn-string'
  properties: {
    value: storageConnString
  }
}

resource StorageEndpoint 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-endpoint'
  properties: {
    value: storage.properties.primaryEndpoints.blob
  }
}

resource StorageContainer 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-container'
  properties: {
    value: storageContainerName
  }
}

resource SPClient 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sp-client-id'
  properties: {
    value: spClientID
  }
}

resource SPTenantId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sp-tenant-id'
  properties: {
    value: spTenantID
  }
}

resource SPSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sp-secret'
  properties: {
    value: spSecret
  }
}

// ---- OUTPUTS ----
output keyVaultUri string = keyVault.properties.vaultUri
