targetScope = 'subscription'

@description('Name of the resource group')
param rgName string

@description('The name of the virtual network')
param vnetName string

@description('The name of Agents Subnet')
param agentSubnetName string

@description('The name of Hub subnet')
param peSubnetName string

@description('The name of VM subnet')
param vmSubnetName string

@description('Name of the VM')
param vmName string

@description('Name of the Network Interface')
param nicName string

@description('Name of the Network Security Group')
param nsgName string

@description('Name of the Public IP')
param publicIpName string

@description('Admin username for VM')
param adminUsername string

@secure()
@description('Admin password for VM')
param adminPassword string

@description('Name of the User Assigned Managed Identity')
param uamiName string

@description('Location for the resource group and its resources')
param location string

@description('Location for the sql resources')
param sql_location string

@description('Name of the Azure Cognitive Search service')
param searchServiceName string

@description('Name of the Azure Cognitive Search service Index')
param searchIndexName string

@description('Name of the SQL Server')
param sqlServerName string

@description('Administrator login for the SQL Server')
param sqlAdminLogin string

@description('Name of Embedding Model.')
param embeddingModel string

@description('Name of the Model.')
param modelName string

@description('Service Principal (SP) Tenant ID')
param spTenantID string

@description('Service Principal (SP) Secret')
param spSecret string

@description('Service Principal (SP) Client ID')
param spPrincipalID string

@description('Client ID of the Service Principal (SP)')
param spClientID string

@secure()
@description('SerpAPI key. Do NOT hardcode.')
param serpApiKey string

@secure()
@description('Administrator password for the SQL Server')
param sqlAdminPassword string

@description('Name of the SQL Database')
param sqlDatabaseName string

@description('Name of the Key Vault to create')
param KeyVaultName string

@description('Endpoint of the SQL Server')
param sqlServerURL string

@description('Hub workspace name (AI Hub)')
param hubName string
@description('Project workspace name (linked to hub)')
param projectName string
// e.g. /subscriptions/.../resourceGroups/rg.../providers/Microsoft.Search/searchServices/medical-docs

@description('Name of the Azure Container Registry')
param containerRegistryname string

@description('AOAI/AI model deployments to attach to connections (optional)')
param modelDeployments array = []

@description('Custom subdomain name for the workspace')
param domainName string

@description('Azure AI Services account name')
param aiName string

@description('Tags to apply to Hub, Project, and AIServices')
param tags object = {}

@description('Name of the storage account to create')
param storageName string = '${projectName}storage'

@description('Array of containers to create.')
param containerNames array

@description('Log Analytics workspace name')
param logAnalyticsWorkspaceName string

@description('Location for the Azure Cognitive Search service')
param semantic_location string

@description('Object mapping DNS zone names to their resource group, or empty string to indicate creation')
param existingDnsZones object

// Create the resource group
module resourceGroup './modules/resourceGroups.bicep' = {
  name: 'createResourceGroup'
  params: {
    resourceGroupName: rgName
    resourceGroupLocation: location
  }
}

module vnet './modules/vnet.bicep' = {
  name: 'CreateVNet'
  params: {
    agentSubnetName: agentSubnetName
    peSubnetName: peSubnetName
    vnetName: vnetName
    vmSubnetName: vmSubnetName
    vnetLocation: location
  }
  scope: az.resourceGroup(rgName)
}

// (Optional) Create a VM for testing connectivity

module vm './modules/virtual_machine.bicep' = {
  scope: az.resourceGroup(rgName)
  name: 'CreateVM'
  params: {
    vnetName: vnetName
    adminUsername: adminUsername
    nicName: nicName
    nsgName: nsgName
    publicIpName: publicIpName
    subnetName: vmSubnetName
    vmName: vmName
    adminPassword: adminPassword
  }
  dependsOn: [vnet]
}

module uami './modules/uami.bicep' = {
  name: 'CreateUAMI'
  params: {
    uamiName: uamiName
  }
  scope: az.resourceGroup(rgName)
}

// Azure Cognitive Search service

module search './modules/ai_search.bicep' = {
  name: 'deploySearchService'
  scope: az.resourceGroup(rgName)
  params: {
    searchServiceName: searchServiceName
    searchLocation: semantic_location
  }
}

// SQL Server and Database

module sql './modules/sql.bicep' = {
  name: 'deploySqlServerWithDatabase'
  scope: az.resourceGroup(rgName)
  params: {
    sqlServerName: sqlServerName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    location: sql_location
    sqlDatabaseName: sqlDatabaseName
  }
}

module logAnalytics './modules/log_analytics.bicep' = {
  name: 'deployLogAnalytics'
  scope: az.resourceGroup(rgName)
  params: {
    location: location
    tags: tags
    logAnalyticsWorkspacename: logAnalyticsWorkspaceName
  }
}

module appInsights './modules/app_insights.bicep' = {
  name: 'deployAppInsights'
  scope: az.resourceGroup(rgName)
  params: {
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    AppInsightsname: '${projectName}-appinsights'
    location: location
  }
}

module storage './modules/storage.bicep' = {
  name: 'deployStorageAccount'
  scope: az.resourceGroup(rgName)
  params: {
    containerNames: containerNames
    storageName: storageName
    tags: tags
    location: location
  }
}

module keyVault './modules/key_vault.bicep' = {
  name: 'deployKeyVault'
  scope: az.resourceGroup(rgName)
  params: {
    keyVaultname: KeyVaultName
    location: location
    tags: tags
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
  }
}

module containerRegistry './modules/container_registry.bicep' = {
  name: 'deployContainerRegistry'
  scope: az.resourceGroup(rgName)
  params: {
    location: location
    acrName: containerRegistryname
  }
}

module ai './modules/ai_services.bicep' = {
  name: 'deployAIServices'
  scope: az.resourceGroup(rgName)
  params: {
    aiName: aiName
    location: semantic_location
    modelDeployments: modelDeployments
    customSubDomainName: domainName
    tags: tags
  }
}

// Workspace
module workspace './modules/hub&connections.bicep' = {
  name: 'workspaces'
  scope: az.resourceGroup(rgName)
  params: {
    location: semantic_location
    hubName: hubName
    storageName: storageName
    appInsightsName: appInsights.name
    keyVaultId: keyVault.outputs.keyVaultId
    aiName: aiName
    containerRegistryname: containerRegistryname
    searchServiceName: searchServiceName
  }
  dependsOn: [ai, storage, containerRegistry, search]
}

module project './modules/project.bicep' = {
  name: 'projectWorkspace'
  scope: az.resourceGroup(rgName)
  params: {
    aiServicesPrincipalId: ai.outputs.aiServicesPrincipalId
    projectName: projectName
    location: semantic_location
    hubname: hubName
  }
  dependsOn: [workspace]
}

module Role './modules/rbac.bicep' = {
  name: 'RoleAssignment'
  scope: az.resourceGroup(rgName)
  params: {
    principalId: project.outputs.projectPrincipalId
    keyVaultName: keyVault.outputs.keyVaultName
    // aiName: aiName
    // projectIdentityObjectId: project.outputs.projectWorkspaceId
  }
}

module UAMIRole './modules/rbac_uami.bicep' = {
  name: 'RoleAssignmentForUami'
  scope: az.resourceGroup(rgName)
  params: {
    principalId: uami.outputs.uamiPrincipalId
    keyVaultName: keyVault.outputs.keyVaultName
    acrName: containerRegistryname
    aiName: aiName
    searchServiceName: searchServiceName
    projectName: projectName
    spPrincipalId: spPrincipalID
  }
  dependsOn: [containerRegistry, ai, search, project]
}

module keys './modules/add_secrets.bicep' = {
  name: 'AddingKeysToVault'
  params: {
    aiName: aiName
    embeddingModel: embeddingModel
    hubName: hubName
    keyVaultName: KeyVaultName
    modelName: modelName
    rgName: rgName
    searchIndexName: searchIndexName
    searchServiceName: searchServiceName
    serpApiKey: serpApiKey
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    sqlDatabaseName: sqlDatabaseName
    sqlServerURL: sqlServerURL
    projectName: projectName
    spClientID: spClientID
    spSecret: spSecret
    spTenantID: spTenantID
    storageAccountName: storageName
    storageContainerName: containerNames[0]
  }
  scope: az.resourceGroup(rgName)
  dependsOn: [keyVault, search, sql, project, workspace, ai]
}

module privateEndpointAndDNS './modules/private_endpoints.bicep' = {
  name: 'CreatingPrivateEndpoint'
  scope: az.resourceGroup(rgName)
  params: {
    aiAccountName: aiName // AI Services to secure
    aiSearchName: searchServiceName // AI Search to secure
    storageName: storageName // Storage to secure
    vnetName: vnet.outputs.virtualNetworkName // VNet containing subnets
    peSubnetName: vnet.outputs.peSubnetName // Subnet for private endpoints
    existingDnsZones: existingDnsZones
  }
  dependsOn: [ai, search, storage, project, workspace]
}

output sqlServerId string = sql.outputs.sqlServerId
output sqlDatabaseId string = sql.outputs.sqlDatabaseId
output searchServiceId string = search.outputs.searchServiceId
output searchServiceEndpoint string = search.outputs.searchServiceEndpoint
output rg string = resourceGroup.outputs.resourceGroupNameOut
output projectWorkspaceId string = project.outputs.projectWorkspaceId
output keyVaultUri string = keyVault.outputs.keyVaultUri
output acrName string = containerRegistryname
output acrLoginServer string = containerRegistry.outputs.acrLoginServer
output containerAppEnv string = 'poc1-aca-env'
output containerAppName string = 'poc1-aca-app'
output resourceGroupName string = rgName
output location string = location
output logAnalyticsName string = logAnalyticsWorkspaceName
output uamiId string = uami.outputs.uamiID
output uamiPrincipalId string = uami.outputs.uamiPrincipalId
output uamiClientId string = uami.outputs.uamiClientId
output spPrincipalID string = spPrincipalID
output spClientID string = spClientID
output spTenantID string = spTenantID
output spSecret string = spSecret
