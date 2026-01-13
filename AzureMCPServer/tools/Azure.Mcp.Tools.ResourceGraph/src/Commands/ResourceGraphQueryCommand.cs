// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System.Text.Json.Serialization;
using Azure.Mcp.Core.Commands;
using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Tools.ResourceGraph.Options;
using Azure.Mcp.Tools.ResourceGraph.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.ResourceGraph.Commands;

/// <summary>
/// Queries Azure Resource Graph (ARG) for information about resources, subscriptions, subscription IDs,
/// or resource groups that the user has access to in Azure including any Azure resource types.
/// </summary>
public sealed class ResourceGraphQueryCommand(ILogger<ResourceGraphQueryCommand> logger) : GlobalCommand<ResourceGraphQueryOptions>()
{
    private const string CommandTitle = "Query Azure Resource Graph";
    private readonly ILogger<ResourceGraphQueryCommand> _logger = logger;

    public override string Id => "c3d4e5f6-a7b8-9012-cdef-345678901234";

    public override string Name => "query";

    public override string Description =>
        """
        Queries Azure Resource Graph (ARG) for information about resources, subscriptions, subscription IDs,
        or resource groups that the user has access to in Azure including any Azure resource types including
        Azure Functions, Azure App Services, virtual machines, Azure Cache for Redis, virtual networks, etc.
        This tool should be used to obtain details about the user's resources (such as resource id, status,
        OS type, disk type, SKU, size, etc.), subscriptions (such as subscription id, subscription name, etc.),
        or resource groups (such as resource group id, name, etc.). If the user is asking about THEIR RESOURCES
        then this tool IS appropriate. This tool should NOT be used to generally learn about Azure resources.
        If the user is asking CONCEPTUAL QUESTIONS about Azure resources, this tool IS NOT appropriate.
        The query parameter should be a valid Kusto Query Language (KQL) query.
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

    protected override void RegisterOptions(Command command)
    {
        base.RegisterOptions(command);
        command.Options.Add(ResourceGraphOptionDefinitions.Query);
        command.Options.Add(ResourceGraphOptionDefinitions.Subscriptions);
    }

    protected override ResourceGraphQueryOptions BindOptions(ParseResult parseResult)
    {
        var options = base.BindOptions(parseResult);
        options.Query = parseResult.GetValueOrDefault<string>(ResourceGraphOptionDefinitions.Query.Name);
        options.Subscriptions = parseResult.GetValueOrDefault<string[]>(ResourceGraphOptionDefinitions.Subscriptions.Name);
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
            var resourceGraphService = context.GetService<IResourceGraphService>();

            var result = await resourceGraphService.ExecuteQueryAsync(
                options.Query!,
                options.Subscriptions,
                options.Tenant,
                options.RetryPolicy,
                cancellationToken);

            var commandResult = new ResourceGraphQueryCommandResult(
                Data: result.Data,
                TotalRecords: result.TotalRecords,
                Count: result.Count,
                SkipToken: result.SkipToken);

            context.Response.Results = ResponseResult.Create(commandResult, ResourceGraphJsonContext.Default.ResourceGraphQueryCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error executing Resource Graph query. Query: {Query}, Options: {@Options}", options.Query, options);
            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ResourceGraphQueryCommandResult(
        [property: JsonPropertyName("data")] string Data,
        [property: JsonPropertyName("totalRecords")] long TotalRecords,
        [property: JsonPropertyName("count")] long Count,
        [property: JsonPropertyName("skipToken")] string? SkipToken);
}
