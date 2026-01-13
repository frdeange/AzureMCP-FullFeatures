// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;

namespace Azure.Mcp.Core.Areas.Auth.Commands;

[JsonSerializable(typeof(AuthContextGetCommand.AuthContextGetCommandResult))]
[JsonSerializable(typeof(AuthContextGetCommand.TenantInfo))]
[JsonSerializable(typeof(AuthContextGetCommand.SubscriptionInfo))]
[JsonSerializable(typeof(List<AuthContextGetCommand.TenantInfo>))]
[JsonSerializable(typeof(List<AuthContextGetCommand.SubscriptionInfo>))]
[JsonSerializable(typeof(AuthContextSetCommand.AuthContextSetCommandResult))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
internal partial class AuthJsonContext : JsonSerializerContext
{
}
