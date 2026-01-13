// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;
using Azure.Mcp.Core.Options;

namespace Azure.Mcp.Core.Areas.Auth.Options;

public class AuthContextSetOptions : GlobalOptions
{
    [JsonPropertyName("subscription")]
    public string? Subscription { get; set; }
}
