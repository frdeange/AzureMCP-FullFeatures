// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Options;

namespace Azure.Mcp.Tools.Cosmos.Services;

public interface ICosmosService : IDisposable
{
    Task<List<string>> GetCosmosAccounts(
        string subscription,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    Task<List<string>> ListDatabases(
        string accountName,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    Task<List<string>> ListContainers(
        string accountName,
        string databaseName,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    Task<List<JsonElement>> QueryItems(
        string accountName,
        string databaseName,
        string containerName,
        string? query,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Creates a new item in the specified container.
    /// </summary>
    /// <returns>Result containing success status, id, and partition key.</returns>
    /// <exception cref="Exception">Throws with status code 409 if item already exists.</exception>
    Task<ItemOperationResult> CreateItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string item,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Creates or updates an item in the specified container.
    /// </summary>
    /// <returns>Result containing success status, id, and partition key.</returns>
    Task<ItemOperationResult> UpsertItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string item,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Gets a single item by id and partition key.
    /// </summary>
    /// <returns>The item as a JsonElement.</returns>
    /// <exception cref="Exception">Throws with status code 404 if item not found.</exception>
    Task<JsonElement> GetItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string itemId,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Deletes an item by id and partition key.
    /// </summary>
    /// <returns>Result containing success status and id.</returns>
    /// <exception cref="Exception">Throws with status code 404 if item not found.</exception>
    Task<ItemOperationResult> DeleteItemAsync(
        string accountName,
        string databaseName,
        string containerName,
        string itemId,
        string partitionKey,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Creates a new container in the specified database.
    /// </summary>
    /// <returns>Result containing success status, container name, and partition key path.</returns>
    /// <exception cref="Exception">Throws with status code 409 if container already exists.</exception>
    Task<ContainerOperationResult> CreateContainerAsync(
        string accountName,
        string databaseName,
        string containerName,
        string partitionKeyPath,
        int? throughput,
        string subscription,
        AuthMethod authMethod = AuthMethod.Credential,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Result of an item operation (create, upsert, delete).
/// </summary>
public record ItemOperationResult(bool Success, string Id, string PartitionKey);

/// <summary>
/// Result of a container operation (create).
/// </summary>
public record ContainerOperationResult(bool Success, string Container, string PartitionKeyPath);
