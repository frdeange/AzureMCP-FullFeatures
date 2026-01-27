// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Tools.Cosmos.Options;
using Azure.Mcp.Tools.Cosmos.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.Cosmos.Commands;

public sealed class ItemGetCommand(ILogger<ItemGetCommand> logger) : BaseContainerCommand<ItemReadOptions>()
{
    private const string CommandTitle = "Get Cosmos DB Item";
    private readonly ILogger<ItemGetCommand> _logger = logger;

    public override string Id => "a1b2c3d4-3333-4444-8888-000000000003";

    public override string Name => "get";

    public override string Description =>
        "Retrieve a single item/document from a Cosmos DB container by its id and partition key. Returns 404 Not Found if the item does not exist.";

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

            var item = await cosmosService.GetItemAsync(
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
                new ItemGetCommandResult(item),
                CosmosJsonContext.Default.ItemGetCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An exception occurred getting item. Account: {Account}, Database: {Database}, Container: {Container}, ItemId: {ItemId}",
                options.Account, options.Database, options.Container, options.ItemId);

            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ItemGetCommandResult(JsonElement Item);
}
