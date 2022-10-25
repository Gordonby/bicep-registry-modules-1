param newTags object
param resourceId string

var existingTags = reference(extensionResourceId(resourceId, 'Microsoft.Resources/tags', 'default'), '2021-04-01').tags
var mergedTags = union(existingTags, newTags)

resource default 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  scope: reference(extensionResourceId(resourceId, 'Microsoft.Resources/tags', 'default'), '2021-04-01')
  properties: {
    tags: mergedTags
  }
}

output mergedTags object = mergedTags
