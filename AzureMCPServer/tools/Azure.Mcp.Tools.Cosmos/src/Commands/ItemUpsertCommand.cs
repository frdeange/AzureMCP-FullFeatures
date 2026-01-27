// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Tools.Cosmos.Options;
using Azure.Mcp.Tools.Cosmos.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Mcp.Core.Commands;
using Microsoft.Mcp.Core.Models.Command;

namespace Azure.Mcp.Tools.Cosmos.Commands;

public sealed class ItemUpsertCommand(ILogger<ItemUpsertCommand> logger) : BaseContainerCommand<ItemWriteOptions>()
{
    private const string CommandTitle = "Upsert Cosmos DB Item";
    private readonly ILogger<ItemUpsertCommand> _logger = logger;

    public override string Id => "a1b2c3d4-2222-4444-8888-000000000002";

    public override string Name => "upsert";

    public override string Description =>
        "Create or update an item/document in a Cosmos DB container. The item must include an 'id' property. If the item exists, it will be replaced; otherwise, a new item will be created.";

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

            var result = await cosmosService.UpsertItemAsync(
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
                new ItemUpsertCommandResult(result.Success, result.Id, result.PartitionKey),
                CosmosJsonContext.Default.ItemUpsertCommandResult);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An exception occurred upserting item. Account: {Account}, Database: {Database}, Container: {Container}",
                options.Account, options.Database, options.Container);

            HandleException(context, ex);
        }

        return context.Response;
    }

    internal record ItemUpsertCommandResult(bool Success, string Id, string PartitionKey);
}
