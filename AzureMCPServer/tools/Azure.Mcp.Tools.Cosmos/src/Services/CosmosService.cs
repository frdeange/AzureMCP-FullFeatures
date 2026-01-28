// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Net;
using Azure.Mcp.Core.Options;
using Azure.Mcp.Core.Services.Azure;
using Azure.Mcp.Core.Services.Azure.Subscription;
using Azure.Mcp.Core.Services.Azure.Tenant;
using Azure.Mcp.Core.Services.Caching;
using Azure.ResourceManager.CosmosDB;
using Microsoft.Azure.Cosmos;

namespace Azure.Mcp.Tools.Cosmos.Services;

public class CosmosService(ISubscriptionService subscriptionService, ITenantService tenantService, ICacheService cacheService)
    : BaseAzureService(tenantService), ICosmosService, IDisposable
{
    private readonly ISubscriptionService _subscriptionService = subscriptionService ?? throw new ArgumentNullException(nameof(subscriptionService));
    private readonly ICacheService _cacheService = cacheService ?? throw new ArgumentNullException(nameof(cacheService));
    private const string CosmosBaseUri = "https://{0}.documents.azure.com:443/";
    private const string CacheGroup = "cosmos";
    private const string CosmosClientsCacheKeyPrefix = "clients_";
    private const string CosmosDatabasesCacheKeyPrefix = "databases_";
    private const string CosmosContainersCacheKeyPrefix = "containers_";
    private static readonly TimeSpan s_cacheDurationResources = TimeSpan.FromMinutes(15);
    private bool _disposed;

    private async Task<CosmosDBAccountResource> GetCosmosAccountAsync(
        string subscription,
        string accountName,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null)
    {
        ValidateRequiredParameters((nameof(subscription), subscription), (nameof(accountName), accountName));

        var subscriptionResource = await _subscriptionService.GetSubscription(subscription, tenant, retryPolicy);

        await foreach (var account in subscriptionResource.GetCosmosDBAccountsAsync())
        {
            if (account.Data.Name == accountName)
            {
                return account;
            }
        }
        throw new Exception($"Cosmos DB account '{accountName}' not found in subscription '{subscription}'");
    }

    private async Task<CosmosClient> CreateCosmosClientWithAuth(
        string accountName,
        string subscription,
        AuthMethod authMethod,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        // Enable bulk execution and distributed tracing telemetry features once they are supported by the Microsoft.Azure.Cosmos.Aot package.
        // var clientOptions = new CosmosClientOptions { AllowBulkExecution = true };
        // clientOptions.CosmosClientTelemetryOptions.DisableDistributedTracing = false;
        var clientOptions = new CosmosClientOptions();
        clientOptions.CustomHandlers.Add(new UserPolicyRequestHandler(UserAgent));

        if (retryPolicy != null)
        {
            clientOptions.MaxRetryAttemptsOnRateLimitedRequests = retryPolicy.MaxRetries;
            clientOptions.MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(retryPolicy.MaxDelaySeconds);
        }

        CosmosClient cosmosClient;
        switch (authMethod)
        {
            case AuthMethod.Key:
                var cosmosAccount = await GetCosmosAccountAsync(subscription, accountName, tenant);
                var keys = await cosmosAccount.GetKeysAsync(cancellationToken);
                cosmosClient = new CosmosClient(
                    string.Format(CosmosBaseUri, accountName),
                    keys.Value.PrimaryMasterKey,
                    clientOptions);
                break;

            case AuthMethod.Credential:
            default:
                cosmosClient = new CosmosClient(
                    string.Format(CosmosBaseUri, accountName),
                    await GetCredential(cancellationToken),
                    clientOptions);
                break;
        }

        // Validate the client by performing a lightweight operation
        await ValidateCosmosClientAsync(cosmosClient, cancellationToken);

        return cosmosClient;
    }

    private async Task ValidateCosmosClientAsync(CosmosClient client, CancellationToken cancellationToken = default)
    {
        try
        {
            // Perform a lightweight operation to validate the client
            await client.ReadAccountAsync();
        }
        catch (CosmosException ex)
        {
            throw new Exception($"Failed to validate CosmosClient: {ex.StatusCode} - {ex.Message}", ex);
        }
        catch (Exception ex)
        {
            throw new Exception($"Unexpected error while validating CosmosClient: {ex.Message}", ex);
        }
    }

    private async Task<CosmosClient> GetCosmosClientAsync(
        string accountName,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters((nameof(accountName), accountName), (nameof(subscription), subscription));

        var key = CosmosClientsCacheKeyPrefix + accountName;
        var cosmosClient = await _cacheService.GetAsync<CosmosClient>(CacheGroup, key, s_cacheDurationResources, cancellationToken);
        if (cosmosClient != null)
            return cosmosClient;

        try
        {
            // First attempt with requested auth method
            cosmosClient = await CreateCosmosClientWithAuth(
                accountName,
                subscription,
                authMethod,
                tenant,
                retryPolicy,
                cancellationToken);

            await _cacheService.SetAsync(CacheGroup, key, cosmosClient, s_cacheDurationResources, cancellationToken);
            return cosmosClient;
        }
        catch (Exception ex) when (
            authMethod == AuthMethod.Credential &&
            (ex.Message.Contains(((int)HttpStatusCode.Unauthorized).ToString()) || ex.Message.Contains(((int)HttpStatusCode.Forbidden).ToString())))
        {
            // If credential auth fails with 401/403, try key auth
            cosmosClient = await CreateCosmosClientWithAuth(
                accountName,
                subscription,
                AuthMethod.Key,
                tenant,
                retryPolicy,
                cancellationToken);

            await _cacheService.SetAsync(CacheGroup, key, cosmosClient, s_cacheDurationResources, cancellationToken);
            return cosmosClient;
        }

        throw new Exception($"Failed to create Cosmos client for account '{accountName}' with any authentication method");
    }

    public async Task<List<string>> GetCosmosAccounts(string subscription, string? tenant = null, RetryPolicyOptions? retryPolicy = null, CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters((nameof(subscription), subscription));

        var subscriptionResource = await _subscriptionService.GetSubscription(subscription, tenant, retryPolicy, cancellationToken);
        var accounts = new List<string>();
        try
        {
            await foreach (var account in subscriptionResource.GetCosmosDBAccountsAsync(cancellationToken))
            {
                if (account?.Data?.Name != null)
                {
                    accounts.Add(account.Data.Name);
                }
            }
        }
        catch (Exception ex)
        {
            throw new Exception($"Error retrieving Cosmos DB accounts: {ex.Message}", ex);
        }

        return accounts;
    }

    public async Task<List<string>> ListDatabases(
        string accountName,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters((nameof(accountName), accountName), (nameof(subscription), subscription));

        var cacheKey = CosmosDatabasesCacheKeyPrefix + accountName;

        var cachedDatabases = await _cacheService.GetAsync<List<string>>(CacheGroup, cacheKey, s_cacheDurationResources, cancellationToken);
        if (cachedDatabases != null)
        {
            return cachedDatabases;
        }

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);
        var databases = new List<string>();

        try
        {
            var iterator = client.GetDatabaseQueryStreamIterator();
            while (iterator.HasMoreResults)
            {
                using ResponseMessage dbResponse = await iterator.ReadNextAsync(cancellationToken);
                if (!dbResponse.IsSuccessStatusCode)
                {
                    throw new Exception(dbResponse.ErrorMessage);
                }
                using JsonDocument dbsQueryResultDoc = JsonDocument.Parse(dbResponse.Content);
                if (dbsQueryResultDoc.RootElement.TryGetProperty("Databases", out JsonElement documentsElement))
                {
                    foreach (JsonElement databaseElement in documentsElement.EnumerateArray())
                    {
                        string? databaseId = databaseElement.GetProperty("id").GetString();
                        if (!string.IsNullOrEmpty(databaseId))
                        {
                            databases.Add(databaseId);
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            throw new Exception($"Error listing databases in the account '{accountName}': {ex.Message}", ex);
        }

        await _cacheService.SetAsync(CacheGroup, cacheKey, databases, s_cacheDurationResources, cancellationToken);
        return databases;
    }

    public async Task<List<string>> ListContainers(
        string accountName,
        string databaseName,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters((nameof(accountName), accountName), (nameof(databaseName), databaseName), (nameof(subscription), subscription));

        var cacheKey = CosmosContainersCacheKeyPrefix + accountName + "_" + databaseName;

        var cachedContainers = await _cacheService.GetAsync<List<string>>(CacheGroup, cacheKey, s_cacheDurationResources, cancellationToken);
        if (cachedContainers != null)
        {
            return cachedContainers;
        }

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);
        var containers = new List<string>();

        try
        {
            var database = client.GetDatabase(databaseName);
            var iterator = database.GetContainerQueryStreamIterator();
            while (iterator.HasMoreResults)
            {
                using ResponseMessage containerRResponse = await iterator.ReadNextAsync(cancellationToken);
                if (!containerRResponse.IsSuccessStatusCode)
                {
                    throw new Exception(containerRResponse.ErrorMessage);
                }
                using JsonDocument containersQueryResultDoc = JsonDocument.Parse(containerRResponse.Content);
                if (containersQueryResultDoc.RootElement.TryGetProperty("DocumentCollections", out JsonElement containersElement))
                {
                    foreach (JsonElement containerElement in containersElement.EnumerateArray())
                    {
                        string? containerId = containerElement.GetProperty("id").GetString();
                        if (!string.IsNullOrEmpty(containerId))
                        {
                            containers.Add(containerId);
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            throw new Exception($"Error listing containers in database '{databaseName}' of account '{accountName}': {ex.Message}", ex);
        }

        await _cacheService.SetAsync(CacheGroup, cacheKey, containers, s_cacheDurationResources, cancellationToken);
        return containers;
    }

    public async Task<List<JsonElement>> QueryItems(
        string accountName,
        string databaseName,
        string containerName,
        string? query,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters((nameof(accountName), accountName), (nameof(databaseName), databaseName), (nameof(containerName), containerName), (nameof(subscription), subscription));

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);

        try
        {
            var container = client.GetContainer(databaseName, containerName);
            var baseQuery = string.IsNullOrEmpty(query) ? "SELECT * FROM c" : query;
            var queryDef = new QueryDefinition(baseQuery);

            var items = new List<JsonElement>();
            var queryIterator = container.GetItemQueryStreamIterator(
                queryDef,
                requestOptions: new QueryRequestOptions { MaxItemCount = -1 }
            );

            while (queryIterator.HasMoreResults)
            {
                using ResponseMessage response = await queryIterator.ReadNextAsync(cancellationToken);
                using var document = JsonDocument.Parse(response.Content);
                items.Add(document.RootElement.Clone());
            }

            return items;
        }
        catch (CosmosException ex)
        {
            throw new Exception($"Cosmos DB error occurred while querying items: {ex.StatusCode} - {ex.Message}", ex);
        }
        catch (Exception ex)
        {
            throw new Exception($"Error querying items: {ex.Message}", ex);
        }
    }

    public async Task<ItemOperationResult> CreateItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string item,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters(
            (nameof(accountName), accountName),
            (nameof(databaseName), databaseName),
            (nameof(containerName), containerName),
            (nameof(item), item),
            (nameof(partitionKey), partitionKey),
            (nameof(subscription), subscription));

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);

        try
        {
            var container = client.GetContainer(databaseName, containerName);
            using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(item));

            var response = await container.CreateItemStreamAsync(
                stream,
                new PartitionKey(partitionKey),
                cancellationToken: cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                if (response.StatusCode == HttpStatusCode.Conflict)
                {
                    throw new Exception($"409 Conflict: Item already exists in container '{containerName}'");
                }
                throw new Exception($"{(int)response.StatusCode} {response.StatusCode}: {response.ErrorMessage}");
            }

            // Extract id from the item JSON
            using var doc = JsonDocument.Parse(item);
            var id = doc.RootElement.GetProperty("id").GetString() ?? "";

            return new ItemOperationResult(true, id, partitionKey);
        }
        catch (CosmosException ex)
        {
            throw new Exception($"{(int)ex.StatusCode} {ex.StatusCode}: {ex.Message}", ex);
        }
    }

    public async Task<ItemOperationResult> UpsertItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string item,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters(
            (nameof(accountName), accountName),
            (nameof(databaseName), databaseName),
            (nameof(containerName), containerName),
            (nameof(item), item),
            (nameof(partitionKey), partitionKey),
            (nameof(subscription), subscription));

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);

        try
        {
            var container = client.GetContainer(databaseName, containerName);
            using var stream = new MemoryStream(System.Text.Encoding.UTF8.GetBytes(item));

            var response = await container.UpsertItemStreamAsync(
                stream,
                new PartitionKey(partitionKey),
                cancellationToken: cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                throw new Exception($"{(int)response.StatusCode} {response.StatusCode}: {response.ErrorMessage}");
            }

            // Extract id from the item JSON
            using var doc = JsonDocument.Parse(item);
            var id = doc.RootElement.GetProperty("id").GetString() ?? "";

            return new ItemOperationResult(true, id, partitionKey);
        }
        catch (CosmosException ex)
        {
            throw new Exception($"{(int)ex.StatusCode} {ex.StatusCode}: {ex.Message}", ex);
        }
    }

    public async Task<JsonElement> GetItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string itemId,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters(
            (nameof(accountName), accountName),
            (nameof(databaseName), databaseName),
            (nameof(containerName), containerName),
            (nameof(itemId), itemId),
            (nameof(partitionKey), partitionKey),
            (nameof(subscription), subscription));

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);

        try
        {
            var container = client.GetContainer(databaseName, containerName);

            var response = await container.ReadItemStreamAsync(
                itemId,
                new PartitionKey(partitionKey),
                cancellationToken: cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                if (response.StatusCode == HttpStatusCode.NotFound)
                {
                    throw new Exception($"404 NotFound: Item '{itemId}' not found in container '{containerName}'");
                }
                throw new Exception($"{(int)response.StatusCode} {response.StatusCode}: {response.ErrorMessage}");
            }

            using var doc = await JsonDocument.ParseAsync(response.Content, cancellationToken: cancellationToken);
            return doc.RootElement.Clone();
        }
        catch (CosmosException ex)
        {
            throw new Exception($"{(int)ex.StatusCode} {ex.StatusCode}: {ex.Message}", ex);
        }
    }

    public async Task<ItemOperationResult> DeleteItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string itemId,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters(
            (nameof(accountName), accountName),
            (nameof(databaseName), databaseName),
            (nameof(containerName), containerName),
            (nameof(itemId), itemId),
            (nameof(partitionKey), partitionKey),
            (nameof(subscription), subscription));

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);

        try
        {
            var container = client.GetContainer(databaseName, containerName);

            var response = await container.DeleteItemStreamAsync(
                itemId,
                new PartitionKey(partitionKey),
                cancellationToken: cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                if (response.StatusCode == HttpStatusCode.NotFound)
                {
                    throw new Exception($"404 NotFound: Item '{itemId}' not found in container '{containerName}'");
                }
                throw new Exception($"{(int)response.StatusCode} {response.StatusCode}: {response.ErrorMessage}");
            }

            return new ItemOperationResult(true, itemId, partitionKey);
        }
        catch (CosmosException ex)
        {
            throw new Exception($"{(int)ex.StatusCode} {ex.StatusCode}: {ex.Message}", ex);
        }
    }

    public async Task<ContainerOperationResult> CreateContainerAsync(
        string accountName,
        string databaseName,
        string containerName,
        string partitionKeyPath,
        int? throughput,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters(
            (nameof(accountName), accountName),
            (nameof(databaseName), databaseName),
            (nameof(containerName), containerName),
            (nameof(partitionKeyPath), partitionKeyPath),
            (nameof(subscription), subscription));

        try
        {
            // Use ARM SDK to create containers (AOT compatible)
            var cosmosAccount = await GetCosmosAccountAsync(subscription, accountName, tenant, retryPolicy);

            // Get the SQL database collection and then the specific database
            var sqlDatabases = cosmosAccount.GetCosmosDBSqlDatabases();
            var sqlDatabaseResponse = await sqlDatabases.GetAsync(databaseName, cancellationToken);
            var sqlDatabase = sqlDatabaseResponse.Value;

            // Create container properties
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

            // Add throughput if specified
            if (throughput.HasValue)
            {
                containerData.Options = new CosmosDBCreateUpdateConfig
                {
                    Throughput = throughput.Value
                };
            }

            // Create the container
            var containerCollection = sqlDatabase.GetCosmosDBSqlContainers();
            var operation = await containerCollection.CreateOrUpdateAsync(
                Azure.WaitUntil.Completed,
                containerName,
                containerData,
                cancellationToken);

            return new ContainerOperationResult(true, containerName, partitionKeyPath);
        }
        catch (Azure.RequestFailedException ex) when (ex.Status == 409)
        {
            throw new Exception($"409 Conflict: Container '{containerName}' already exists in database '{databaseName}'", ex);
        }
        catch (Azure.RequestFailedException ex)
        {
            throw new Exception($"{ex.Status} {ex.ErrorCode}: {ex.Message}", ex);
        }
        catch (Exception ex)
        {
            throw new Exception($"Error creating container: {ex.Message}", ex);
        }
    }

    public async Task<JsonElement> GetContainerAsync(
        string accountName,
        string databaseName,
        string containerName,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters(
            (nameof(accountName), accountName),
            (nameof(databaseName), databaseName),
            (nameof(containerName), containerName),
            (nameof(subscription), subscription));

        var client = await GetCosmosClientAsync(accountName, subscription, authMethod, tenant, retryPolicy, cancellationToken);

        try
        {
            var container = client.GetContainer(databaseName, containerName);

            // Read container properties using stream API (AOT compatible)
            using var response = await container.ReadContainerStreamAsync(cancellationToken: cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                if (response.StatusCode == HttpStatusCode.NotFound)
                {
                    throw new Exception($"404 NotFound: Container '{containerName}' not found in database '{databaseName}'");
                }
                throw new Exception($"{(int)response.StatusCode} {response.StatusCode}: {response.ErrorMessage}");
            }

            using var doc = await JsonDocument.ParseAsync(response.Content, cancellationToken: cancellationToken);
            var containerProperties = doc.RootElement.Clone();

            // Try to get throughput (returns null for serverless)
            int? throughput = null;
            try
            {
                throughput = await container.ReadThroughputAsync(cancellationToken);
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
            {
                // Throughput not configured at container level (might be at database level or serverless)
                throughput = null;
            }

            // Build result with container properties and throughput using Utf8JsonWriter (AOT compatible)
            using var memoryStream = new MemoryStream();
            using (var writer = new Utf8JsonWriter(memoryStream))
            {
                writer.WriteStartObject();

                // Copy relevant properties from container response
                if (containerProperties.TryGetProperty("id", out var idProp))
                {
                    writer.WriteString("id", idProp.GetString());
                }

                if (containerProperties.TryGetProperty("partitionKey", out var pkProp))
                {
                    if (pkProp.TryGetProperty("paths", out var pathsProp))
                    {
                        var paths = new List<string>();
                        foreach (var path in pathsProp.EnumerateArray())
                        {
                            var pathStr = path.GetString();
                            if (pathStr != null) paths.Add(pathStr);
                        }

                        if (paths.Count > 0)
                        {
                            writer.WriteString("partitionKeyPath", paths[0]);
                        }

                        writer.WriteStartArray("partitionKeyPaths");
                        foreach (var p in paths)
                        {
                            writer.WriteStringValue(p);
                        }
                        writer.WriteEndArray();
                    }
                }

                if (containerProperties.TryGetProperty("defaultTtl", out var ttlProp))
                {
                    writer.WriteNumber("defaultTimeToLive", ttlProp.GetInt32());
                }

                if (containerProperties.TryGetProperty("indexingPolicy", out var indexProp))
                {
                    writer.WritePropertyName("indexingPolicy");
                    indexProp.WriteTo(writer);
                }

                if (containerProperties.TryGetProperty("uniqueKeyPolicy", out var uniqueProp))
                {
                    writer.WritePropertyName("uniqueKeyPolicy");
                    uniqueProp.WriteTo(writer);
                }

                if (containerProperties.TryGetProperty("_etag", out var etagProp))
                {
                    writer.WriteString("etag", etagProp.GetString());
                }

                if (containerProperties.TryGetProperty("_ts", out var tsProp))
                {
                    writer.WriteNumber("lastModifiedTimestamp", tsProp.GetInt64());
                }

                if (throughput.HasValue)
                {
                    writer.WriteNumber("throughput", throughput.Value);
                }
                else
                {
                    writer.WriteNull("throughput");
                }

                writer.WriteEndObject();
            }

            memoryStream.Position = 0;
            using var resultDoc = await JsonDocument.ParseAsync(memoryStream, cancellationToken: cancellationToken);
            return resultDoc.RootElement.Clone();
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            throw new Exception($"404 NotFound: Container '{containerName}' not found in database '{databaseName}'", ex);
        }
        catch (Exception ex) when (ex is not Exception { Message: string msg } || !msg.StartsWith("404"))
        {
            throw new Exception($"Error getting container '{containerName}': {ex.Message}", ex);
        }
    }

    protected virtual async void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
            {
                // Get all cached client keys
                var keys = await _cacheService.GetGroupKeysAsync(CacheGroup, CancellationToken.None);

                // Filter for client keys only (those that start with the client prefix)
                var clientKeys = keys.Where(k => k.StartsWith(CosmosClientsCacheKeyPrefix));

                // Retrieve and dispose each client
                foreach (var key in clientKeys)
                {
                    var client = await _cacheService.GetAsync<CosmosClient>(CacheGroup, key);
                    client?.Dispose();
                }
                _disposed = true;
            }
        }
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }

    internal class UserPolicyRequestHandler : RequestHandler
    {
        private readonly string userAgent;

        internal UserPolicyRequestHandler(string userAgent) => this.userAgent = userAgent;

        public override Task<ResponseMessage> SendAsync(RequestMessage request, CancellationToken cancellationToken)
        {
            request.Headers.Set(UserAgentPolicy.UserAgentHeader, userAgent);
            return base.SendAsync(request, cancellationToken);
        }
    }
}
