// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using OpenAvP2.Installation;
using OpenAvP2.Inventory;
using OpenAvP2.Platform;

namespace OpenAvP2;

/// <summary>
/// Registers OpenAvP2 services. Composition lives here so that the game, the
/// dedicated server and the command line tools all build the same object graph
/// rather than each wiring their own.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers the platform and installation services shared by every host.
    /// </summary>
    public static IServiceCollection AddOpenAvP2Core(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.TryAddSingleton<IFileSystem, PhysicalFileSystem>();
        services.TryAddSingleton<IInstallationValidator, InstallationValidator>();

        return services;
    }

    /// <summary>
    /// Registers installation inventory services (roadmap stage 0).
    /// </summary>
    /// <remarks>
    /// Probes are registered as a collection. Format-specific probes are added
    /// here as each format becomes understood, and the orchestrator picks them up
    /// without modification.
    /// </remarks>
    public static IServiceCollection AddInstallationInventory(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddOpenAvP2Core();
        services.TryAddEnumerable(ServiceDescriptor.Singleton<IFormatProbe, SignatureProbe>());
        services.TryAddSingleton<IInventoryWriter, JsonInventoryWriter>();
        services.TryAddSingleton<InventoryOrchestrator>();

        return services;
    }
}
