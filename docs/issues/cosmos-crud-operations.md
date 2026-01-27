# Feature: CosmosDB CRUD Operations

## Summary
Implement 5 new CosmosDB tools to enable complete CRUD (Create, Read, Update, Delete) operations for items and container creation. This enables agents to manage CosmosDB data programmatically.

## Tools Implemented

| Tool | Operation | Description |
|------|-----------|-------------|
| `cosmos_database_container_item_create` | Create | Create a new item (fails if exists - 409) |
| `cosmos_database_container_item_upsert` | Upsert | Create or update an item |
| `cosmos_database_container_item_get` | Read | Read a single item by id and partition key |
| `cosmos_database_container_item_delete` | Delete | Delete an item by id and partition key |
| `cosmos_database_container_create` | Create | Create a new container with partition key |

## Input Schemas

### Item Create / Upsert
- `account` (string, required) - CosmosDB account name
- `database` (string, required) - Database name
- `container` (string, required) - Container name
- `item` (string, required) - JSON document to create/upsert
- `partitionKey` (string, required) - Partition key value

### Item Get / Delete
- `account` (string, required) - CosmosDB account name
- `database` (string, required) - Database name
- `container` (string, required) - Container name
- `itemId` (string, required) - Document id
- `partitionKey` (string, required) - Partition key value

### Container Create
- `account` (string, required) - CosmosDB account name
- `database` (string, required) - Database name
- `container` (string, required) - Container name to create
- `partitionKeyPath` (string, required) - Partition key path (e.g., /productFamily)
- `throughput` (int, optional) - Provisioned RU/s

## Output Schemas

### Item Create / Upsert / Delete
```json
{ "success": true, "id": "document-id", "partitionKey": "partition-key-value" }
```

### Item Get
```json
{ "item": { /* full document */ } }
```

### Container Create
```json
{ "success": true, "container": "container-name", "partitionKeyPath": "/path" }
```

## Error Handling

| Status Code | Meaning | Scenario |
|-------------|---------|----------|
| 404 | Not Found | GET/DELETE on non-existent item or container |
| 409 | Conflict | CREATE on existing item |
| 400 | Bad Request | Invalid JSON, missing partition key |

## Files Modified/Created

### New Files
- `Options/ItemWriteOptions.cs` - Options for create/upsert
- `Options/ItemReadOptions.cs` - Options for get/delete
- `Options/ContainerCreateOptions.cs` - Options for container creation
- `Commands/ItemCreateCommand.cs`
- `Commands/ItemUpsertCommand.cs`
- `Commands/ItemGetCommand.cs`
- `Commands/ItemDeleteCommand.cs`
- `Commands/ContainerCreateCommand.cs`

### Modified Files
- `Options/CosmosOptionDefinitions.cs` - Added PartitionKey, Item, ItemId, PartitionKeyPath, Throughput options
- `Services/ICosmosService.cs` - Added 5 new method signatures
- `Services/CosmosService.cs` - Implemented 5 new methods
- `Commands/CosmosJsonContext.cs` - Added JsonSerializable for 5 result types
- `CosmosSetup.cs` - Registered 5 new commands
- `GlobalUsings.cs` - Added Azure.ResourceManager.CosmosDB.Models

---

## 🔧 Development Challenges & Solutions

### Challenge 1: AOT Compatibility with Microsoft.Azure.Cosmos.Aot

**Problem:** The project uses `Microsoft.Azure.Cosmos.Aot` package for AOT (Ahead-of-Time) compilation compatibility. This package has a **significantly limited API surface** compared to the full `Microsoft.Azure.Cosmos` package.

**Failed Attempts:**
1. `database.CreateContainerAsync(containerProperties, throughput)` - Method does not exist in AOT package
2. `database.DefineContainer(name, partitionKeyPath).CreateAsync()` - Method does not exist in AOT package

**Solution:** Use the **Azure Resource Manager SDK** (`Azure.ResourceManager.CosmosDB`) for container creation instead of the Cosmos SDK. This approach:
- Is fully AOT compatible
- Uses ARM API which is more verbose but reliable
- Required adding `Azure.ResourceManager.CosmosDB.Models` to GlobalUsings.cs

**Code Pattern:**
```csharp
// Get ARM resources
var cosmosAccount = await GetCosmosAccountAsync(subscription, accountName, tenant, retryPolicy);
var sqlDatabases = cosmosAccount.GetCosmosDBSqlDatabases();
var sqlDatabase = (await sqlDatabases.GetAsync(databaseName, cancellationToken)).Value;

// Create container via ARM
var containerData = new CosmosDBSqlContainerCreateOrUpdateContent(
    cosmosAccount.Data.Location,
    new CosmosDBSqlContainerResourceInfo(containerName)
    {
        PartitionKey = new CosmosDBContainerPartitionKey
        {
            Paths = { partitionKeyPath },
            Kind = CosmosDBPartitionKind.Hash
        }
    });

var containerCollection = sqlDatabase.GetCosmosDBSqlContainers();
await containerCollection.CreateOrUpdateAsync(WaitUntil.Completed, containerName, containerData, cancellationToken);
```

### Challenge 2: Stream-based API for Item Operations

**Problem:** The AOT package requires using stream-based methods for item operations.

**Solution:** Use `*StreamAsync` methods:
- `container.CreateItemStreamAsync(stream, partitionKey)`
- `container.UpsertItemStreamAsync(stream, partitionKey)`
- `container.ReadItemStreamAsync(id, partitionKey)`
- `container.DeleteItemStreamAsync(id, partitionKey)`

**Code Pattern:**
```csharp
using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(item));
var response = await container.CreateItemStreamAsync(stream, new PartitionKey(partitionKey), cancellationToken: cancellationToken);
```

### Challenge 3: ARM SDK Response Types

**Problem:** `GetCosmosDBSqlDatabase(name)` returns a `Response<T>` wrapper, not the resource directly.

**Failed Attempt:**
```csharp
var sqlDatabase = cosmosAccount.GetCosmosDBSqlDatabase(databaseName);
sqlDatabase.GetCosmosDBSqlContainers(); // Error: Response<T> does not have this method
```

**Solution:** Use the collection pattern with async Get:
```csharp
var sqlDatabases = cosmosAccount.GetCosmosDBSqlDatabases();
var sqlDatabaseResponse = await sqlDatabases.GetAsync(databaseName, cancellationToken);
var sqlDatabase = sqlDatabaseResponse.Value;
sqlDatabase.GetCosmosDBSqlContainers(); // Works!
```

---

## Design Decisions

1. **Partition Key Required**: Explicitly required to avoid extra API calls and ambiguity
2. **Simple Response**: Success confirmation with id/partitionKey only (no full document return for writes)
3. **Minimal Container Options**: Only partitionKeyPath required, throughput optional
4. **Error Codes**: Parse CosmosException/RequestFailedException to return meaningful HTTP status codes
5. **ARM for Container Creation**: Use Azure.ResourceManager.CosmosDB for AOT compatibility

## Status: ✅ Implemented

All 5 tools have been implemented, build successfully, and are registered in the MCP server.
