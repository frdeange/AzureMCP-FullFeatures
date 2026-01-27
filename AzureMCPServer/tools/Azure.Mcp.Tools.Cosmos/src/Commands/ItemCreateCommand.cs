// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Tools.Cosmos.Options;
using Azure.Mcp.Tools.Cosmos.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.Cosmos.Commands;

public sealed class ItemCreateCommand(ILogger<ItemCreateCommand> logger) : BaseContainerCommand<ItemWriteOptions>()
{
    private const string CommandTitle = "Create Cosmos DB Item";
    private readonly ILogger<ItemCreateCommand> _logger = logger;

    public override string Id => "a1b2c3d4-1111-4444-8888-000000000001";

    public override string Name => "create";

    public override string Description =>
        "Create a new item/document in a Cosmos DB container. The item must include an 'id' property. Fails with 409 Conflict if an item with the same id and partition key already exists.";

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
        command.Options.Add(CosmosOptionDefinitions.Item);
        command.Options.Add(CosmosOptionDefinitions.PartitionKey);
    }

    protected override ItemWriteOptions BindOptions(ParseResult parseResult)
    {
        var options = base.BindOptions(parseResult);
        options.Item = parseResult.GetValueOrDefault<string>(CosmosOptionDefinitions.Item.Name);
        options.PartitionKey = parseResult.GetValueOrDefault<string>(CosmosOptionDefinitions.PartitionKey.Name);
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

            var result = await cosmosService.CreateItemAsync(
                options.Account!,
                options.Database!,
                options.Container!,
                options.Item!,
                options.PartitionKey!,
                options.Subscription!,
                options.AuthMethod ?? AuthMethod.Credential,
                options.Tenant,
                options.RetryPolicy,
                cancellationToken);

            context.Response.Results = ResponseResult.Create(
                new ItemCreateCommandResult(result.Success, result.Id, result.PartitionKey),
                CosmosJsonContext.Default.ItemCreateCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An exception occurred creating item. Account: {Account}, Database: {Database}, Container: {Container}",
                options.Account, options.Database, options.Container);

            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ItemCreateCommandResult(bool Success, string Id, string PartitionKey);
}
