// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Tools.Cosmos.Options;
using Azure.Mcp.Tools.Cosmos.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.Cosmos.Commands;

public sealed class ItemDeleteCommand(ILogger<ItemDeleteCommand> logger) : BaseContainerCommand<ItemReadOptions>()
{
    private const string CommandTitle = "Delete Cosmos DB Item";
    private readonly ILogger<ItemDeleteCommand> _logger = logger;

    public override string Id => "a1b2c3d4-4444-4444-8888-000000000004";

    public override string Name => "delete";

    public override string Description =>
        "Delete an item/document from a Cosmos DB container by its id and partition key. Returns 404 Not Found if the item does not exist.";

    public override string Title => CommandTitle;

    public override ToolMetadata Metadata => new()
    {
        Destructive = true,
        Idempotent = true,
        OpenWorld = false,
        ReadOnly = false,
        LocalRequired = false,
        Secret = false
    };

    protected override void RegisterOptions(Command command)
    {
        base.RegisterOptions(command);
        command.Options.Add(CosmosOptionDefinitions.ItemId);
        command.Options.Add(CosmosOptionDefinitions.PartitionKey);
    }

    protected override ItemReadOptions BindOptions(ParseResult parseResult)
    {
        var options = base.BindOptions(parseResult);
        options.ItemId = parseResult.GetValueOrDefault<string>(CosmosOptionDefinitions.ItemId.Name);
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

            var result = await cosmosService.DeleteItemAsync(
                options.Account!,
                options.Database!,
                options.Container!,
                options.ItemId!,
                options.PartitionKey!,
                options.Subscription!,
                options.AuthMethod ?? AuthMethod.Credential,
                options.Tenant,
                options.RetryPolicy,
                cancellationToken);

            context.Response.Results = ResponseResult.Create(
                new ItemDeleteCommandResult(result.Success, result.Id),
                CosmosJsonContext.Default.ItemDeleteCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An exception occurred deleting item. Account: {Account}, Database: {Database}, Container: {Container}, ItemId: {ItemId}",
                options.Account, options.Database, options.Container, options.ItemId);

            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ItemDeleteCommandResult(bool Success, string Id);
}
