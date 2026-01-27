// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

namespace Azure.Mcp.Tools.Cosmos.Options;

public static class CosmosOptionDefinitions
{
    public const string AccountName = "account";
    public const string DatabaseName = "database";
    public const string ContainerName = "container";
    public const string QueryText = "query";
    public const string PartitionKeyName = "partitionKey";
    public const string ItemName = "item";
    public const string ItemIdName = "itemId";
    public const string PartitionKeyPathName = "partitionKeyPath";
    public const string ThroughputName = "throughput";

    public static readonly Option<string> Account = new(
        $"--{AccountName}"
    )
    {
        Description = "The name of the Cosmos DB account to query (e.g., my-cosmos-account).",
        Required = true
    };

    public static readonly Option<string> Database = new(
        $"--{DatabaseName}"
    )
    {
        Description = "The name of the database to query (e.g., my-database).",
        Required = true
    };

    public static readonly Option<string> Container = new(
        $"--{ContainerName}"
    )
    {
        Description = "The name of the container to query (e.g., my-container).",
        Required = true
    };

    public static readonly Option<string> Query = new(
        $"--{QueryText}"
    )
    {
        Description = "SQL query to execute against the container. Uses Cosmos DB SQL syntax.",
        Required = false,
        DefaultValueFactory = _ => "SELECT * FROM c"
    };

    public static readonly Option<string> PartitionKey = new(
        $"--{PartitionKeyName}"
    )
    {
        Description = "The partition key value for the item.",
        Required = true
    };

    public static readonly Option<string> Item = new(
        $"--{ItemName}"
    )
    {
        Description = "The JSON document to create or update.",
        Required = true
    };

    public static readonly Option<string> ItemId = new(
        $"--{ItemIdName}"
    )
    {
        Description = "The unique identifier of the item to read or delete.",
        Required = true
    };

    public static readonly Option<string> PartitionKeyPath = new(
        $"--{PartitionKeyPathName}"
    )
    {
        Description = "The partition key path for the container (e.g., /productFamily).",
        Required = true
    };

    public static readonly Option<int?> Throughput = new(
        $"--{ThroughputName}"
    )
    {
        Description = "The provisioned throughput in RU/s for the container. If not specified, serverless or autoscale is used.",
        Required = false
    };
}
