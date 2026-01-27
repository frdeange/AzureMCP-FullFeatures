// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;

namespace Azure.Mcp.Tools.Cosmos.Options;

/// <summary>
/// Options for item create and upsert operations.
/// </summary>
public class ItemWriteOptions : BaseContainerOptions
{
    [JsonPropertyName(CosmosOptionDefinitions.ItemName)]
    public string? Item { get; set; }

    [JsonPropertyName(CosmosOptionDefinitions.PartitionKeyName)]
    public string? PartitionKey { get; set; }
}
