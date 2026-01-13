// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;
using Azure.Mcp.Core.Areas.Auth.Options;
using Azure.Mcp.Core.Commands;
using Azure.Mcp.Core.Models.Option;
using Azure.Mcp.Core.Services.Azure.Subscription;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;
using Microsoft.Mcp.Core.Models.Option;

namespace Azure.Mcp.Core.Areas.Auth.Commands;

/// <summary>
/// Modifies the Azure authentication context. Azure authentication context is used by the Azure related
/// tools for the agent. Use this tool when the user expresses the intent to update the Azure authentication
/// context to use. You may suggest this tool if it can be inferred from the conversation that the current
/// Azure authentication context is incorrect.
/// </summary>
public sealed class AuthContextSetCommand(ILogger<AuthContextSetCommand> logger) : GlobalCommand<AuthContextSetOptions>()
{
    private const string CommandTitle = "Set Azure Authentication Context";
    private readonly ILogger<AuthContextSetCommand> _logger = logger;

    public override string Id => "b2c3d4e5-f6a7-8901-bcde-f23456789012";

    public override string Name => "set";

    public override string Description =>
        """
        Modifies the Azure authentication context. Azure authentication context is used by the Azure related
        tools for the agent. Use this tool when the user expresses the intent to update the Azure authentication
        context to use. You may suggest this tool if it can be inferred from the conversation that the current
        Azure authentication context is incorrect. This tool allows setting the default subscription to use
        for subsequent Azure operations.
        """;

    public override string Title => CommandTitle;

    public override ToolMetadata Metadata => new()
    {
        Destructive = false,
        Idempotent = true,
        OpenWorld = false,
        ReadOnly = false,
        LocalRequired = false,
        Secret = false
    };

    protected override void RegisterOptions(Command command)
    {
        base.RegisterOptions(command);
        command.Options.Add(OptionDefinitions.Common.Subscription.AsOptional());
    }

    protected override AuthContextSetOptions BindOptions(ParseResult parseResult)
    {
        var options = base.BindOptions(parseResult);
        options.Subscription = parseResult.GetValueOrDefault<string>(OptionDefinitions.Common.Subscription.Name);
        return options;
    }

    public override async Task<CommandResponse> ExecuteAsync(CommandContext context, ParseResult parseResult, CancellationToken cancellationToken)
    {
        if (!Validate(parseResult.CommandResult, context.Response).IsValid)
        {
            return context.Response;
        }

        var options = BindOptions(parseResult);

        try
        {
            var subscriptionService = context.GetService<ISubscriptionService>();

            string? resolvedSubscriptionId = null;
            string? resolvedSubscriptionName = null;

            // If a subscription was provided, validate it exists
            if (!string.IsNullOrEmpty(options.Subscription))
            {
                // Try to get the subscription to validate it exists
                var subscription = await subscriptionService.GetSubscription(
                    options.Subscription,
                    options.Tenant,
                    options.RetryPolicy,
                    cancellationToken);

                resolvedSubscriptionId = subscription.Data.SubscriptionId;
                resolvedSubscriptionName = subscription.Data.DisplayName;

                // Set the environment variable for subsequent operations
                Environment.SetEnvironmentVariable("AZURE_SUBSCRIPTION_ID", resolvedSubscriptionId);

                _logger.LogInformation(
                    "Authentication context updated. Default subscription set to: {SubscriptionName} ({SubscriptionId})",
                    resolvedSubscriptionName,
                    resolvedSubscriptionId);
            }

            var result = new AuthContextSetCommandResult(
                Success: true,
                Message: !string.IsNullOrEmpty(resolvedSubscriptionId)
                    ? $"Authentication context updated. Default subscription set to: {resolvedSubscriptionName} ({resolvedSubscriptionId})"
                    : "No changes made to authentication context.",
                SubscriptionId: resolvedSubscriptionId,
                SubscriptionName: resolvedSubscriptionName
            );

            context.Response.Results = ResponseResult.Create(result, AuthJsonContext.Default.AuthContextSetCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting authentication context. Subscription: {Subscription}", options.Subscription);
            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record AuthContextSetCommandResult(
        [property: JsonPropertyName("success")] bool Success,
        [property: JsonPropertyName("message")] string Message,
        [property: JsonPropertyName("subscriptionId")] string? SubscriptionId,
        [property: JsonPropertyName("subscriptionName")] string? SubscriptionName
    );
}
