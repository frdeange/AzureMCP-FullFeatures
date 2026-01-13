// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;

namespace Azure.Mcp.Tools.ResourceGraph.Commands;

[JsonSerializable(typeof(ResourceGraphQueryCommand.ResourceGraphQueryCommandResult))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
internal partial class ResourceGraphJsonContext : JsonSerializerContext
{
}
