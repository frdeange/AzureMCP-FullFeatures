// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;

namespace Azure.Mcp.Tools.Cosmos.Commands;

[JsonSerializable(typeof(ContainerListCommand.ContainerListCommandResult))]
[JsonSerializable(typeof(ContainerGetCommand.ContainerGetCommandResult))]
[JsonSerializable(typeof(AccountListCommand.AccountListCommandResult))]
[JsonSerializable(typeof(DatabaseListCommand.DatabaseListCommandResult))]
[JsonSerializable(typeof(ItemQueryCommand.ItemQueryCommandResult))]
[JsonSerializable(typeof(ItemCreateCommand.ItemCreateCommandResult))]
[JsonSerializable(typeof(ItemUpsertCommand.ItemUpsertCommandResult))]
[JsonSerializable(typeof(ItemGetCommand.ItemGetCommandResult))]
[JsonSerializable(typeof(ItemDeleteCommand.ItemDeleteCommandResult))]
[JsonSerializable(typeof(ContainerCreateCommand.ContainerCreateCommandResult))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
internal sealed partial class CosmosJsonContext : JsonSerializerContext
{
}
