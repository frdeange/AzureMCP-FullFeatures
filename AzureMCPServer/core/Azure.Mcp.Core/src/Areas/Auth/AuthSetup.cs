// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using Azure.Mcp.Core.Areas.Auth.Commands;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Mcp.Core.Areas;
using Microsoft.Mcp.Core.Commands;

namespace Azure.Mcp.Core.Areas.Auth;

public class AuthSetup : IAreaSetup
{
    public string Name => "auth";

    public string Title => "Azure Authentication Context Management";

    public void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<AuthContextGetCommand>();
        services.AddSingleton<AuthContextSetCommand>();
    }

    public CommandGroup RegisterCommands(IServiceProvider serviceProvider)
    {
        // Create Auth command group
        var auth = new CommandGroup(
            Name,
            """
            Azure authentication context operations - Commands for getting and setting the Azure authentication
            context used by Azure related tools. Use these commands to view the current authentication state
            including available tenants, subscriptions, and default settings, or to modify the authentication
            context when needed.
            """,
            Title);

        // Create context subgroup
        var context = new CommandGroup(
            "context",
            "Authentication context operations - Commands for viewing and modifying the Azure authentication context.");
        auth.AddSubGroup(context);

        // Register Auth commands
        var getCommand = serviceProvider.GetRequiredService<AuthContextGetCommand>();
        context.AddCommand(getCommand.Name, getCommand);

        var setCommand = serviceProvider.GetRequiredService<AuthContextSetCommand>();
        context.AddCommand(setCommand.Name, setCommand);

        return auth;
    }
}
