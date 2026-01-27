// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Tools.Cosmos.Options;
using Azure.Mcp.Tools.Cosmos.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.Cosmos.Commands;

public sealed class ContainerCreateCommand(ILogger<ContainerCreateCommand> logger) : BaseDatabaseCommand<ContainerCreateOptions>()
{
    private const string CommandTitle = "Create Cosmos DB Container";
    private readonly ILogger<ContainerCreateCommand> _logger = logger;

    public override string Id => "a1b2c3d4-5555-4444-8888-000000000005";

    public override string Name => "create";

    public override string Description =>
        "Create a new container in a Cosmos DB database. Requires a partition key path (e.g., /productFamily). Optionally specify throughput in RU/s.";

    public override string Title => CommandTitle;

    public override ToolMetadata Metadata => new()
    {
        Destructive = true,
        Idempotent = false,
        OpenWorld = false,
        ReadOnly = false,
        LocalRequired = false,
        Secret = false
    };

    protected override void RegisterOptions(Command command)
    {
        base.RegisterOptions(command);
        command.Options.Add(CosmosOptionDefinitions.Container);
        command.Options.Add(CosmosOptionDefinitions.PartitionKeyPath);
        command.Options.Add(CosmosOptionDefinitions.Throughput);
    }

    protected override ContainerCreateOptions BindOptions(ParseResult parseResult)
    {
        var options = base.BindOptions(parseResult);
        options.Container = parseResult.GetValueOrDefault<string>(CosmosOptionDefinitions.Container.Name);
        options.PartitionKeyPath = parseResult.GetValueOrDefault<string>(CosmosOptionDefinitions.PartitionKeyPath.Name);
        options.Throughput = parseResult.GetValueOrDefault<int?>(CosmosOptionDefinitions.Throughput.Name);
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
            var cosmosService = context.GetService<ICosmosService>();

            var result = await cosmosService.CreateContainerAsync(
                options.Account!,
                options.Database!,
                options.Container!,
                options.PartitionKeyPath!,
                options.Throughput,
                options.Subscription!,
                options.AuthMethod ?? AuthMethod.Credential,
                options.Tenant,
                options.RetryPolicy,
                cancellationToken);

            context.Response.Results = ResponseResult.Create(
                new ContainerCreateCommandResult(result.Success, result.Container, result.PartitionKeyPath),
                CosmosJsonContext.Default.ContainerCreateCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An exception occurred creating container. Account: {Account}, Database: {Database}, Container: {Container}",
                options.Account, options.Database, options.Container);

            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ContainerCreateCommandResult(bool Success, string Container, string PartitionKeyPath);
}
