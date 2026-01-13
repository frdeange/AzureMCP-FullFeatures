// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;
using Azure.Mcp.Core.Areas.Auth.Options;
using Azure.Mcp.Core.Commands;
using Azure.Mcp.Core.Models.Option;
using Azure.Mcp.Core.Services.Azure.Subscription;
using Azure.Mcp.Core.Services.Azure.Tenant;
using Azure.ResourceManager.Resources;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Core.Areas.Auth.Commands;

/// <summary>
/// Gets the full Azure Authentication context that will be used by Azure related tools for the agent.
/// Use this tool to inform the user when they ask for such information or when they express
/// that the authentication context being used is incorrect.
/// </summary>
public sealed class AuthContextGetCommand(ILogger<AuthContextGetCommand> logger) : GlobalCommand<AuthContextGetOptions>()
{
    private const string CommandTitle = "Get Azure Authentication Context";
    private readonly ILogger<AuthContextGetCommand> _logger = logger;

    public override string Id => "a1b2c3d4-e5f6-7890-abcd-ef1234567890";

    public override string Name => "get";

    public override string Description =>
        """
        Gets the full Azure Authentication context that will be used by Azure related tools for the agent.
        Use this tool to inform the user when they ask for such information or when they express
        that the authentication context being used is incorrect. Returns information about the current
        tenant, available subscriptions, and the default subscription being used.
        """;

    public override string Title => CommandTitle;

    public override ToolMetadata Metadata => new()
    {
        Destructive = false,
        Idempotent = true,
        OpenWorld = false,
        ReadOnly = true,
        LocalRequired = false,
        Secret = false
    };

    public override async Task<CommandResponse> ExecuteAsync(CommandContext context, ParseResult parseResult, CancellationToken cancellationToken)
    {
        if (!Validate(parseResult.CommandResult, context.Response).IsValid)
        {
            return context.Response;
        }

        var options = BindOptions(parseResult);

        try
        {
            var tenantService = context.GetService<ITenantService>();
            var subscriptionService = context.GetService<ISubscriptionService>();

            // Get available tenants
            var tenants = await tenantService.GetTenants(cancellationToken);
            var tenantInfos = tenants.Select(t => new TenantInfo(
                TenantId: t.Data.TenantId?.ToString(),
                DisplayName: t.Data.DisplayName,
                DefaultDomain: t.Data.DefaultDomain
            )).ToList();

            // Get available subscriptions
            var subscriptions = await subscriptionService.GetSubscriptions(options.Tenant, options.RetryPolicy, cancellationToken);
            var subscriptionInfos = subscriptions.Select(s => new SubscriptionInfo(
                SubscriptionId: s.SubscriptionId,
                DisplayName: s.DisplayName,
                State: s.State?.ToString(),
                TenantId: s.TenantId?.ToString()
            )).ToList();

            // Get default subscription from environment variable if set
            var defaultSubscriptionId = Environment.GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID");
            string? defaultSubscriptionName = null;
            if (!string.IsNullOrEmpty(defaultSubscriptionId))
            {
                var defaultSub = subscriptions.FirstOrDefault(s =>
                    s.SubscriptionId.Equals(defaultSubscriptionId, StringComparison.OrdinalIgnoreCase));
                defaultSubscriptionName = defaultSub?.DisplayName;
            }

            var result = new AuthContextGetCommandResult(
                Tenants: tenantInfos,
                Subscriptions: subscriptionInfos,
                DefaultSubscriptionId: defaultSubscriptionId,
                DefaultSubscriptionName: defaultSubscriptionName,
                DefaultTenant: options.Tenant
            );

            context.Response.Results = ResponseResult.Create(result, AuthJsonContext.Default.AuthContextGetCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting authentication context.");
            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record AuthContextGetCommandResult(
        [property: JsonPropertyName("tenants")] List<TenantInfo> Tenants,
        [property: JsonPropertyName("subscriptions")] List<SubscriptionInfo> Subscriptions,
        [property: JsonPropertyName("defaultSubscriptionId")] string? DefaultSubscriptionId,
        [property: JsonPropertyName("defaultSubscriptionName")] string? DefaultSubscriptionName,
        [property: JsonPropertyName("defaultTenant")] string? DefaultTenant
    );

    internal record TenantInfo(
        [property: JsonPropertyName("tenantId")] string? TenantId,
        [property: JsonPropertyName("displayName")] string? DisplayName,
        [property: JsonPropertyName("defaultDomain")] string? DefaultDomain
    );

    internal record SubscriptionInfo(
        [property: JsonPropertyName("subscriptionId")] string? SubscriptionId,
        [property: JsonPropertyName("displayName")] string? DisplayName,
        [property: JsonPropertyName("state")] string? State,
        [property: JsonPropertyName("tenantId")] string? TenantId
    );
}
