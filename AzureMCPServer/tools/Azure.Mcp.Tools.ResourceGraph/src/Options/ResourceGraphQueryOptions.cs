// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;
using Azure.Mcp.Core.Options;

namespace Azure.Mcp.Tools.ResourceGraph.Options;

public class ResourceGraphQueryOptions : GlobalOptions
{
    [JsonPropertyName(ResourceGraphOptionDefinitions.QueryName)]
    public string? Query { get; set; }

    [JsonPropertyName(ResourceGraphOptionDefinitions.SubscriptionsName)]
    public string[]? Subscriptions { get; set; }
}
