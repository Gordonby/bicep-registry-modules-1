param location string = resourceGroup().location

var cleanStorageAccountName = take(toLower('st${uniqueString(resourceGroup().id,deployment().name)}'),24)

// resource storageaccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
//   name: cleanStorageAccountName
//   location: location
//   kind: 'StorageV2'
//   sku: {
//     name: 'Standard_LRS'
//   }
//   tags: { createdIn: 'BicepMainTest' }
// }

module appendTagColour '../main.bicep' = {
  name: 'appendTagTest-AddColour'
  params: {
    newTags: { colour: 'blue' }
    resourceId: existingStorage.id
  }
}

resource existingStorage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: cleanStorageAccountName
}

resource default 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  scope: existingStorage
  properties: {
    tags: appendTagColour.outputs.mergedTags
  }
}

// module appendFood '../main.bicep' = {
//   name: 'appendTagTest-AddFood'
//   params: {
//     newTags: { veg: 'sprouts', meat: 'pulled pork' }
//     resourceId: existingStorage.id
//   }
//   dependsOn: [appendTagColour]
// }
