// sql.bicep
targetScope = 'resourceGroup'

@description('Azure region for the SQL Server and Database (e.g., eastasia, eastus, westeurope).')
param location string

@description('Name of the SQL Server (3-63 chars, lowercase letters, numbers, and hyphens).')
@minLength(3)
@maxLength(63)
param sqlServerName string

@description('Administrator login for the SQL Server.')
@minLength(1)
param sqlAdminLogin string

@secure()
@description('Administrator password for the SQL Server.')
param sqlAdminPassword string

@description('Name of the SQL Database.')
@minLength(1)
param sqlDatabaseName string

@description('Max database size in GB.')
@minValue(1)
param maxSizeGB int = 32

@description('Whether the database is zone redundant (only supported in some regions/SKUs).')
param zoneRedundant bool = false

@description('Database collation.')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'

@description('vCore SKU: tier/family/capacity. Example: GeneralPurpose / Gen5 / 2.')
param skuTier string = 'GeneralPurpose'
param skuFamily string = 'Gen5'

@minValue(1)
param skuCapacity int = 2

@description('Create built-in firewall rule to allow Azure services (0.0.0.0).')
param allowAzureServices bool = true

// @description('Optional firewall rules. Provide an array of objects: [{ name: "office", startIp: "x.x.x.x", endIp: "x.x.x.x" }].')
// param firewallRules array = []

// ---------------------------
// SQL Server
// ---------------------------
resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// Optional: allow Azure services
resource firewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2024-05-01-preview' = if (allowAzureServices) {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// // Optional: custom firewall rules
// @batchSize(1)
// resource firewallCustom 'Microsoft.Sql/servers/firewallRules@2024-05-01-preview' = [
//   for rule in firewallRules: {
//     name: string(rule.name)
//     parent: sqlServer
//     properties: {
//       startIpAddress: string(rule.startIp)
//       endIpAddress: string(rule.endIp)
//     }
//   }
// ]

// ---------------------------
// SQL Database
// ---------------------------
var maxSizeBytes = maxSizeGB * 1024 * 1024 * 1024

resource sqlDb 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'GP_Gen5_${skuCapacity}'
    tier: skuTier
    family: skuFamily
    capacity: skuCapacity
  }
  properties: {
    collation: collation
    maxSizeBytes: maxSizeBytes
    zoneRedundant: zoneRedundant
    licenseType: 'LicenseIncluded'
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
}

output sqlServerId string = sqlServer.id
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseId string = sqlDb.id
