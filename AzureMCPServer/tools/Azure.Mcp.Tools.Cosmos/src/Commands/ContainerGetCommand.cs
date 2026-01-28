// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Tools.Cosmos.Options;
using Azure.Mcp.Tools.Cosmos.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.Cosmos.Commands;

public sealed class ContainerGetCommand(ILogger<ContainerGetCommand> logger) : BaseContainerCommand<ContainerGetOptions>()
{
    private const string CommandTitle = "Get Cosmos DB Container";
    private readonly ILogger<ContainerGetCommand> _logger = logger;

    public override string Id => "a1b2c3d4-4444-5555-9999-000000000004";

    public override string Name => "get";

    public override string Description =>
        """
        Retrieve detailed metadata for a specific Cosmos DB container, including partition key path(s),
        indexing policy, unique key policy, default TTL, throughput (RU/s), and more.
        Use this command to discover the partition key configuration before creating or querying items.
        Returns 404 Not Found if the container does not exist.
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
            var cosmosService = context.GetService<ICosmosService>();

            var containerDetails = await cosmosService.GetContainerAsync(
                options.Account!,
                options.Database!,
                options.Container!,
                options.Subscription!,
                options.AuthMethod ?? AuthMethod.Credential,
                options.Tenant,
                options.RetryPolicy,
                cancellationToken);

            context.Response.Results = ResponseResult.Create(
                new ContainerGetCommandResult(containerDetails),
                CosmosJsonContext.Default.ContainerGetCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An exception occurred getting container. Account: {Account}, Database: {Database}, Container: {Container}",
                options.Account, options.Database, options.Container);

            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ContainerGetCommandResult(JsonElement Container);
}
