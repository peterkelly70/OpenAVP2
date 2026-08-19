// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors
//
// installinventory -- scan an AvP2 installation and write a machine-readable
// manifest of everything it contains (roadmap stage 0).
//
//   installinventory <installation-path> [--out report.json] [--no-probe]
//
// This file is a composition root and nothing else: it parses arguments, builds
// the service provider, and hands off to the orchestrator.

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using OpenAvP2;
using OpenAvP2.Inventory;

if (args.Length == 0 || args[0] is "-h" or "--help")
{
    Console.Error.WriteLine("""
        Usage: installinventory <installation-path> [options]

          --out <file>   Write the report to a file instead of standard output.
          --no-probe     Record names and sizes only; do not open any file.

        Scans an Aliens vs. Predator 2 installation and reports every extension,
        with files grouped by their observed leading bytes so that the number of
        distinct format variants can be counted before any format is documented.
        """);
    return args.Length == 0 ? 2 : 0;
}

var installationPath = args[0];
string? outputPath = null;
var probeContents = true;

for (var i = 1; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--out" when i + 1 < args.Length:
            outputPath = args[++i];
            break;
        case "--no-probe":
            probeContents = false;
            break;
        default:
            Console.Error.WriteLine($"Unrecognised option: {args[i]}");
            return 2;
    }
}

using var provider = new ServiceCollection()
    .AddLogging(builder => builder
        .AddSimpleConsole(options => options.SingleLine = true)
        .SetMinimumLevel(LogLevel.Information))
    .AddInstallationInventory()
    .BuildServiceProvider();

var orchestrator = provider.GetRequiredService<InventoryOrchestrator>();
var writer = provider.GetRequiredService<IInventoryWriter>();

InventoryReport report;
try
{
    report = orchestrator.Scan(installationPath, new InventoryOptions { ProbeContents = probeContents });
}
catch (DirectoryNotFoundException ex)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

using var destination = outputPath is null
    ? Console.OpenStandardOutput()
    : File.Create(outputPath);

writer.Write(report, destination);

// A directory that is not a valid installation is still reported, but the exit
// code distinguishes it so that scripts and CI can tell the difference.
return report.IsValidInstallation ? 0 : 1;
