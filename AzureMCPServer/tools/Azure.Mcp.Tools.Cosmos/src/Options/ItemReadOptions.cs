// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;

namespace Azure.Mcp.Tools.Cosmos.Options;

/// <summary>
/// Options for item get and delete operations.
/// </summary>
public class ItemReadOptions : BaseContainerOptions
{
    [JsonPropertyName(CosmosOptionDefinitions.ItemIdName)]
    public string? ItemId { get; set; }

    [JsonPropertyName(CosmosOptionDefinitions.PartitionKeyName)]
    public string? PartitionKey { get; set; }
}
