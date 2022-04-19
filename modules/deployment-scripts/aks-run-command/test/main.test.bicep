/*

Forcing a RBAC refresh
Azure Resource Manager sometimes caches configurations and data to improve performance.
When you assign roles or remove role assignments, it can take up to 30 minutes for changes to take effect.
If you are using ...Azure CLI, you can force a refresh of your role assignment changes by signing out and signing in.
*/

param location string = resourceGroup().location
param aksName string =  'crtestbjvuodwnit73q' //'crtest${uniqueString(newGuid())}'
param managedIdentityName string = 'id-crtest${uniqueString(newGuid())}'

//RBAC RoleId vars
var contributor='b24988ac-6180-42a0-ab88-20f7382dd24c'
var rbacClusterAdmin='b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
var rbacWriter='a7ffa36f-339b-4b5c-8bdf-e2c188b2c0eb'
var rbacReader='7f6c6a51-bcf8-42ba-9220-52d62157d7db'

//Prerequisites
resource aks 'Microsoft.ContainerService/managedClusters@2022-01-02-preview' = {
  location: location
  name: aksName
  properties: {
    dnsPrefix: aksName
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    agentPoolProfiles: [
      {
        name: 'np01'
        mode: 'System'
        vmSize: 'Standard_DS2_v2'
        count: 2
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }
}

//Test 1. Get Nodes
module kubectlGetNodes '../main.bicep' = {
  name: 'kubectlgetnodes'
  params: {
    managedIdentityName: managedIdentityName
    rbacRolesNeeded:[
      contributor
      rbacClusterAdmin
    ]
    aksName: aksName
    location: location
    commands: [
      'kubectl get nodes'
    ]
  }
}

//Test 2. Get Pods
module kubectlGetPods '../main.bicep' = {
  name: 'kubectlGetPods'
  params: {
    managedIdentityName: 'kubectlGetPods'
    rbacRolesNeeded:[
      contributor
      rbacReader
    ]
    aksName: aksName
    location: location
    commands: [
      'kubectl get pods'
    ]
  }
}

//Test 3. Install Nginx and Get Pods
module kubectlRunNginx '../main.bicep' = {
  name: 'kubectlRunNginx'
  params: {
    managedIdentityName: 'kubectlRunNginx'
    rbacRolesNeeded:[
      contributor
      rbacWriter
    ]
    aksName: aksName
    location: location
    commands: [
      'kubectl run nginx --image=nginx'
      'kubectl get pods'
    ]
  }
}

//Test 4. Helm
module helmContour '../main.bicep' = {
  name: 'helmContour'
  params: {
    managedIdentityName: 'helmContourIngress'
    rbacRolesNeeded:[
      contributor
      rbacWriter
    ]
    aksName: aksName
    location: location
    commands: [
      'helm version'
      'helm repo add bitnami https://charts.bitnami.com/bitnami; helm repo update'
      'helm upgrade --install  contour-ingress bitnami/contour --version 7.7.1 --namespace ingress-basic --create-namespace --set envoy.kind=deployment --set contour.service.externalTrafficPolicy=cluster'
    ]
  }
}