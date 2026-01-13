// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Options;
using Azure.Mcp.Core.Services.Azure;
using Azure.Mcp.Core.Services.Azure.Subscription;
using Azure.Mcp.Core.Services.Azure.Tenant;
using Azure.ResourceManager.ResourceGraph;
using Azure.ResourceManager.ResourceGraph.Models;
using Microsoft.Extensions.Logging;

namespace Azure.Mcp.Tools.ResourceGraph.Services;

public class ResourceGraphService(
    ISubscriptionService subscriptionService,
    ITenantService tenantService,
    ILogger<ResourceGraphService> logger) : BaseAzureService(tenantService), IResourceGraphService
{
    private readonly ISubscriptionService _subscriptionService = subscriptionService;
    private readonly ILogger<ResourceGraphService> _logger = logger;

    public async Task<ResourceGraphQueryResult> ExecuteQueryAsync(
        string query,
        string[]? subscriptions = null,
        string? tenant = null,
        RetryPolicyOptions? retryPolicy = null,
        CancellationToken cancellationToken = default)
    {
        ValidateRequiredParameters((nameof(query), query));

        try
        {
            // Get tenants to execute the query
            var tenants = await TenantService.GetTenants(cancellationToken);
            var currentTenant = tenants.FirstOrDefault()
                ?? throw new InvalidOperationException("No accessible tenants found");

            // Build the query content
            var queryContent = new ResourceQueryContent(query);

            // If specific subscriptions are provided, resolve them
            if (subscriptions != null && subscriptions.Length > 0)
            {
                foreach (var sub in subscriptions)
                {
                    // Resolve subscription ID (handles both IDs and names)
                    string subscriptionId;
                    if (Guid.TryParse(sub, out _))
                    {
                        subscriptionId = sub;
                    }
                    else
                    {
                        subscriptionId = await _subscriptionService.GetSubscriptionIdByName(sub, tenant, retryPolicy, cancellationToken);
                    }
                    queryContent.Subscriptions.Add(subscriptionId);
                }
            }
            else
            {
                // If no subscriptions specified, check for default subscription
                var defaultSubscriptionId = Environment.GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID");
                if (!string.IsNullOrEmpty(defaultSubscriptionId))
                {
                    queryContent.Subscriptions.Add(defaultSubscriptionId);
                }
                else
                {
                    // Query all accessible subscriptions
                    var allSubscriptions = await _subscriptionService.GetSubscriptions(tenant, retryPolicy, cancellationToken);
                    foreach (var sub in allSubscriptions)
                    {
                        queryContent.Subscriptions.Add(sub.SubscriptionId);
                    }
                }
            }

            _logger.LogInformation(
                "Executing Resource Graph query against {SubscriptionCount} subscription(s)",
                queryContent.Subscriptions.Count);

            // Execute the query
            var result = await currentTenant.GetResourcesAsync(queryContent, cancellationToken);

            if (result?.Value == null)
            {
                return new ResourceGraphQueryResult(
                    Data: "[]",
                    TotalRecords: 0,
                    Count: 0,
                    SkipToken: null);
            }

            // Get the data as string
            var dataString = result.Value.Data.ToString();

            return new ResourceGraphQueryResult(
                Data: dataString,
                TotalRecords: result.Value.TotalRecords,
                Count: result.Value.Count,
                SkipToken: result.Value.SkipToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing Resource Graph query: {Query}", query);
            throw;
        }
    }
}
