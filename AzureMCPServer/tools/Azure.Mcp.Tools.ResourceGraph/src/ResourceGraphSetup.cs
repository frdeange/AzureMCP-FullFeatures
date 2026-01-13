// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Tools.ResourceGraph.Commands;
using Azure.Mcp.Tools.ResourceGraph.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Mcp.Core.Areas;
using Microsoft.Mcp.Core.Commands;

namespace Azure.Mcp.Tools.ResourceGraph;

public class ResourceGraphSetup : IAreaSetup
{
    public string Name => "resourcegraph";

    public string Title => "Azure Resource Graph";

    public void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<IResourceGraphService, ResourceGraphService>();
        services.AddSingleton<ResourceGraphQueryCommand>();
    }

    public CommandGroup RegisterCommands(IServiceProvider serviceProvider)
    {
        var resourceGraph = new CommandGroup(
            Name,
            """
            Azure Resource Graph operations - Commands for querying Azure Resource Graph (ARG) to get information
            about resources, subscriptions, and resource groups that the user has access to in Azure. Use this tool
            to obtain details about the user's Azure resources including resource IDs, status, configuration, and
            metadata. This tool executes Kusto Query Language (KQL) queries against Azure Resource Graph and returns
            structured data about Azure resources. Note that this tool requires appropriate Azure permissions and
            will only access resources accessible to the authenticated user.
            """,
            Title);

        // Register the query command
        var queryCommand = serviceProvider.GetRequiredService<ResourceGraphQueryCommand>();
        resourceGraph.AddCommand(queryCommand.Name, queryCommand);

        return resourceGraph;
    }
}
