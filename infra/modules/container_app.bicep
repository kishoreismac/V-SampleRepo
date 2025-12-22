targetScope = 'resourceGroup'

@description('Log Analytics Workspace name for Container App logs')
param logAnalyticsWorkspaceName string

@description('Location')
param location string = resourceGroup().location

@description('Container App name')
param appName string

@description('Container image (e.g., myacr.azurecr.io/chainlit:latest)')
param image string

@description('ACR login server (e.g., myacr.azurecr.io)')
param acrLoginServer string

@description('Key Vault name (where your secrets live)')
param keyVaultName string

@secure()
@description('Key Vault DNS url')
param keyVaultUrl string

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
}

// Observability
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' existing = {
  name: split(acrLoginServer, '.')[0]
}

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${appName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: listKeys(law.id, '2020-08-01').primarySharedKey
      }
    }
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
        allowInsecure: false
        customDomains: [] // optional custom domain
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: 'system' // use MI to pull from ACR (grant pull role below)
        }
      ]
      secrets: [
        // OPTIONAL: if you want to bind secret names directly (Key Vault ref via MI)
        {
          name: 'kv-url'
          value: keyVaultUrl
        }
      ]
      // Environment variables for your app
      // You can keep them plain or KeyVault-ref via DAPR/ACA addons; simplest is just provide KEYVAULT_URL
      // and resolve secrets in code using DefaultAzureCredential.
      // App reads: KEYVAULT_URL, plus any non-secret config
      // Moved to template.environmentVariables below
    }
    template: {
      containers: [
        {
          name: 'app'
          image: image
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            { name: 'KEYVAULT_URL', value: keyVaultUrl }
            // Non-secret config examples:
            // { name: 'AZURE_OPENAI_API_VERSION', value: '2024-10-21' },
            // { name: 'AZURE_OPENAI_CHAT_COMPLETION_DEPLOYED_MODEL_NAME', value: 'gpt-4o' },
            // { name: 'SEARCH_INDEX_NAME', value: 'acc-guidelines-index' },
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

resource acrRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(app.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    ) // AcrPull
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(app.id, 'kvsecretsuser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    ) // Key Vault Secrets User
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output url string = app.properties.configuration.ingress.fqdn
