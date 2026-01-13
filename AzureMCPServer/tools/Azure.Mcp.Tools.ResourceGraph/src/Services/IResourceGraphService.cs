// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Options;

namespace Azure.Mcp.Tools.ResourceGraph.Services;

public interface IResourceGraphService
{
    /// <summary>
    /// Executes an Azure Resource Graph query and returns the results.
    /// </summary>
    /// <param name="query">The KQL query to execute against Azure Resource Graph.</param>
    /// <param name="subscriptions">Optional list of subscription IDs or names to scope the query. If null, queries all accessible subscriptions.</param>
    /// <param name="tenant">Optional tenant ID or name.</param>
    /// <param name="retryPolicy">Optional retry policy configuration.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The query result containing the data and metadata.</returns>
    Task<ResourceGraphQueryResult> ExecuteQueryAsync(
        string query,
        string[]? subscriptions = null,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default);
}

public record ResourceGraphQueryResult(
    string Data,
    long TotalRecords,
    long Count,
    string? SkipToken);
