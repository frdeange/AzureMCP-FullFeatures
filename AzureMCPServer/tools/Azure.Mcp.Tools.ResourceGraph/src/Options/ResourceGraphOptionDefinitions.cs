// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

namespace Azure.Mcp.Tools.ResourceGraph.Options;

public static class ResourceGraphOptionDefinitions
{
    public const string QueryName = "query";
    public const string SubscriptionsName = "subscriptions";

    public static readonly Option<string> Query = new($"--{QueryName}")
    {
        Description = "The Azure Resource Graph query to execute. This should be a valid Kusto Query Language (KQL) query that targets Azure resources.",
        Required = true
    };

    public static readonly Option<string[]> Subscriptions = new($"--{SubscriptionsName}")
    {
        Description = "The subscription IDs or names to scope the query to. If not specified, the query will run against all accessible subscriptions or the default subscription if set.",
        Required = false,
        AllowMultipleArgumentsPerToken = true
    };
}
