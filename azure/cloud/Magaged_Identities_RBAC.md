# Managed Identities and RBAC(Role based access control)
## Managed Identity
### Intro
- User defined ones are separate resources so they are not tied to the lifecycle of the resouce to which they are attached.
- By default, when a resource is generated, there is system-assigned managed identity attached to the resource itself. That managed identity is automatically bound to the lifecycle of the resource that it belongs to.
### Samples
```bicep
param identityName string
param location string = resourceGroup().location

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: location
}

@description('The resource ID of the user-assigned managed identity.')
output managedIdentityResourceId string = managedIdentity.id

@description('The ID of the Azure AD application associated with the managed identity.')
output managedIdentityClientId string = managedIdentity.properties.clientId

@description('The ID of the Azure AD service principal associated with the managed identity.')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
```

### References
- [What are managed identities for Azure resources? - Video](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)

- [Managed identities in Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity?tabs=portal%2Cdotnet)

- [Azure Container Apps image pull with managed identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity-image-pull?tabs=bash&pivots=bicep)

- [Using Managed Identity and Bicep to pull images with Azure Container Apps](https://azureossd.github.io/2023/01/03/Using-Managed-Identity-and-Bicep-to-pull-images-with-Azure-Container-Apps/)


## [Role Assignments](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-rbac)
- Role assignments are [extension resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scope-extension-resources) which modifies or is applied to another resource.
- Role assignments apply at a specific scope, which defines the resource or set of resources that you're granting access to. For more information, see [Understand scope for Azure RBAC](https://learn.microsoft.com/en-us/azure/role-based-access-control/scope-overview).
- If you don't explicitly specify the scope, Bicep uses the file's targetScope.

### Samples
- Minimal setup
```bicep
// For Azure built-in role definitions visit https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var roleDefinitionId = resourceId('microsoft.authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

// You don't have to assign a name to role assignment
//A GUID for the role assignment. It must be unique and different for each role assignment. If omitted, a new GUID is generated.
var roleAssignmentName = guid(mi.name, roleDefinitionId, resourceGroup().id)


resource miRoleAssign 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName //--name
  properties: {
    roleDefinitionId: roleDefinitionId //--role
    principalId: mi.properties.principalId // --assignee-object-id
    principalType: 'ServicePrincipal' //--assignee-principal-type
  }
}

// You have to attach this role assignment to a service or resource
resource stg 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  dependsOn: [
    miRoleAssign
  ]
}
```


- [How to attach multiple role assignments to a single managed identity](https://github.com/Azure/azure-quickstart-templates/blob/master/modules/Microsoft.ManagedIdentity/user-assigned-identity-role-assignment/1.0/main.bicep)

```bicep
// Managed identity  for multiple role assignments
@description('The name of the managed identity resource.')
param managedIdentityName string

@description('Role definition IDs are GUIDs. The IDs of the role definitions to assign to the managed identity. Each role assignment is created at the resource group scope. To find the GUID for built-in Azure role definitions, see https://docs.microsoft.com/azure/role-based-access-control/built-in-roles. You can also use IDs of custom role definitions.')
param roleDefinitionIds array

@description('An optional description to apply to each role assignment, such as the reason this managed identity needs to be granted the role.')
param roleAssignmentDescription string = ''

@description('The Azure location where the managed identity should be created.')
param location string = resourceGroup().location

var roleAssignmentsToCreate = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(managedIdentity.id, resourceGroup().id, roleDefinitionId)
  roleDefinitionId: roleDefinitionId
}]

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for roleAssignmentToCreate in roleAssignmentsToCreate: {
  name: roleAssignmentToCreate.name //--name
  scope: resourceGroup() //scope
  properties: {
    description: roleAssignmentDescription
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: resourceId('microsoft.authorization/roleDefinitions', roleAssignmentToCreate.roleDefinitionId)
    principalType: 'ServicePrincipal' // See https://docs.microsoft.com/azure/role-based-access-control/role-assignments-template#new-service-principal to understand why this property is included.
  }
}]
```
### References