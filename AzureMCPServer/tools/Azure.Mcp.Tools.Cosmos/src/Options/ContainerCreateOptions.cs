// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;

namespace Azure.Mcp.Tools.Cosmos.Options;

/// <summary>
/// Options for container create operation.
/// </summary>
public class ContainerCreateOptions : BaseDatabaseOptions
{
    [JsonPropertyName(CosmosOptionDefinitions.ContainerName)]
    public string? Container { get; set; }

    [JsonPropertyName(CosmosOptionDefinitions.PartitionKeyPathName)]
    public string? PartitionKeyPath { get; set; }

    [JsonPropertyName(CosmosOptionDefinitions.ThroughputName)]
    public int? Throughput { get; set; }
}
