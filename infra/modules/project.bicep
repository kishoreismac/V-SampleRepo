@description('Name of the Azure Machine Learning Project workspace')
param projectName string
@description('Location for the Azure Machine Learning Project workspace')
param location string
@description('Name of the Azure Machine Learning Hub workspace')
param hubname string
@description('Specifies the principal id of the Azure AI Services.')
param aiServicesPrincipalId string

resource hub 'Microsoft.MachineLearningServices/workspaces@2025-06-01' existing = {
  name: hubname
}

resource project 'Microsoft.MachineLearningServices/workspaces@2025-06-01' = {
  name: projectName
  location: location
  sku: { name: 'Basic', tier: 'Basic' }
  kind: 'Project'
  identity: { type: 'SystemAssigned' }
  properties: {
    friendlyName: projectName
    hbiWorkspace: false
    publicNetworkAccess: 'Enabled'
    hubResourceId: hub.id
    enableDataIsolation: true
  }
}

resource azureMLDataScientistRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  scope: subscription()
}

resource azureMLDataScientistManagedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiServicesPrincipalId)) {
  name: guid(project.id, azureMLDataScientistRole.id, aiServicesPrincipalId)
  scope: project
  properties: {
    roleDefinitionId: azureMLDataScientistRole.id
    principalType: 'ServicePrincipal'
    principalId: aiServicesPrincipalId
  }
}

resource cognitiveservicesoaicontributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
  scope: subscription()
}

resource cognitiveservicesoaicontributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiServicesPrincipalId)) {
  name: guid(project.id, cognitiveservicesoaicontributorRole.id, aiServicesPrincipalId)
  scope: project
  properties: {
    roleDefinitionId: cognitiveservicesoaicontributorRole.id
    principalType: 'ServicePrincipal'
    principalId: aiServicesPrincipalId
  }
}

output projectPrincipalId string = project.identity.principalId
output projectWorkspaceId string = project.id
