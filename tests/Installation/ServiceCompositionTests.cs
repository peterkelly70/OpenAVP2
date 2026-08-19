// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using OpenAvP2.Installation;
using OpenAvP2.Inventory;
using OpenAvP2.Platform;
using Xunit;

namespace OpenAvP2.Tests.Installation;

/// <summary>
/// Guards the composition root. A missing or miswired registration is a runtime
/// failure in every host, so it is worth catching in a unit test rather than on
/// first launch.
/// </summary>
public class ServiceCompositionTests
{
    private static ServiceProvider Build() =>
        new ServiceCollection()
            .AddLogging(b => b.SetMinimumLevel(LogLevel.None))
            .AddInstallationInventory()
            .BuildServiceProvider(new ServiceProviderOptions
            {
                ValidateOnBuild = true,
                ValidateScopes = true,
            });

    [Fact]
    public void Composition_ResolvesTheOrchestratorAndItsWholeGraph()
    {
        using var provider = Build();

        Assert.NotNull(provider.GetRequiredService<InventoryOrchestrator>());
    }

    [Theory]
    [InlineData(typeof(IFileSystem))]
    [InlineData(typeof(IInstallationValidator))]
    [InlineData(typeof(IInventoryWriter))]
    public void Composition_RegistersEachService(Type service)
    {
        using var provider = Build();

        Assert.NotNull(provider.GetRequiredService(service));
    }

    [Fact]
    public void Composition_RegistersProbesAsACollection()
    {
        // Format-specific probes are added as each format is understood, so the
        // registration must be enumerable rather than a single service.
        using var provider = Build();

        Assert.NotEmpty(provider.GetRequiredService<IEnumerable<IFormatProbe>>());
    }

    [Fact]
    public void Composition_IsIdempotent()
    {
        // Hosts may call both AddOpenAvP2Core and AddInstallationInventory.
        using var provider = new ServiceCollection()
            .AddLogging(b => b.SetMinimumLevel(LogLevel.None))
            .AddOpenAvP2Core()
            .AddInstallationInventory()
            .AddOpenAvP2Core()
            .BuildServiceProvider();

        Assert.Single(provider.GetRequiredService<IEnumerable<IFormatProbe>>());
    }
}
