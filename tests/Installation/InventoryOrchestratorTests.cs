// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using Microsoft.Extensions.Logging.Abstractions;
using OpenAvP2.Installation;
using OpenAvP2.Inventory;
using OpenAvP2.Platform;
using Xunit;

namespace OpenAvP2.Tests.Installation;

public class InventoryOrchestratorTests
{
    private const string Root = "/games/avp2";

    private static InventoryOrchestrator Orchestrator(
        IFileSystem fileSystem, params IFormatProbe[] probes) =>
        new(fileSystem,
            new InstallationValidator(fileSystem),
            probes.Length == 0 ? [new SignatureProbe()] : probes,
            NullLogger<InventoryOrchestrator>.Instance);

    private static FakeFileSystem ValidInstallation() =>
        new FakeFileSystem().WithFile($"{Root}/avp2.rez", "RezMgr Version 1");

    [Fact]
    public void Scan_CountsFilesAndTotalSize()
    {
        var fs = ValidInstallation()
            .WithFile($"{Root}/sound/effect.wav", new byte[100])
            .WithFile($"{Root}/sound/music.wav", new byte[50]);

        var report = Orchestrator(fs).Scan(Root);

        Assert.Equal(3, report.FileCount);
        Assert.Equal(166, report.TotalBytes); // 16 + 100 + 50
    }

    [Fact]
    public void Scan_GroupsFilesByExtension()
    {
        var fs = ValidInstallation()
            .WithFile($"{Root}/sound/a.wav", new byte[10])
            .WithFile($"{Root}/sound/b.wav", new byte[10]);

        var report = Orchestrator(fs).Scan(Root);

        var wav = Assert.Single(report.Extensions, e => e.Extension == "wav");
        Assert.Equal(2, wav.Count);
        Assert.Equal(20, wav.TotalBytes);
    }

    [Fact]
    public void Scan_NormalisesExtensionCase()
    {
        // Extension case varies across the shipped data; the report must not
        // show DTX and dtx as two different formats.
        var fs = ValidInstallation()
            .WithFile($"{Root}/textures/a.DTX", new byte[4])
            .WithFile($"{Root}/textures/b.dtx", new byte[4]);

        var report = Orchestrator(fs).Scan(Root);

        Assert.Equal(2, Assert.Single(report.Extensions, e => e.Extension == "dtx").Count);
    }

    [Fact]
    public void Scan_CountsDistinctSignaturesWithinAnExtension()
    {
        // This is the point of stage 0: discovering how many variants of a
        // format an installation actually contains, without assuming any.
        var fs = ValidInstallation()
            .WithFile($"{Root}/worlds/a.dat", new byte[] { 0x46, 0x00 })
            .WithFile($"{Root}/worlds/b.dat", new byte[] { 0x46, 0x00 })
            .WithFile($"{Root}/worlds/c.dat", new byte[] { 0x2A, 0x00 });

        var report = Orchestrator(fs).Scan(Root);
        var dat = Assert.Single(report.Extensions, e => e.Extension == "dat");

        Assert.Equal(2, dat.Signatures.Count);
        Assert.Equal(2, dat.Signatures[0].Count); // most common first
        Assert.Equal("4600", dat.Signatures[0].Signature);
    }

    [Fact]
    public void Scan_LimitsExampleCountPerSignature()
    {
        var fs = ValidInstallation();
        for (var i = 0; i < 10; i++)
        {
            fs.WithFile($"{Root}/worlds/w{i}.dat", new byte[] { 0x46 });
        }

        var report = Orchestrator(fs).Scan(Root)
            .Extensions.Single(e => e.Extension == "dat");

        Assert.Equal(3, report.Signatures[0].Examples.Count);
        Assert.Equal(10, report.Signatures[0].Count);
    }

    [Fact]
    public void Scan_RecordsFilesWithNoExtension()
    {
        var fs = ValidInstallation().WithFile($"{Root}/README", new byte[8]);

        var report = Orchestrator(fs).Scan(Root);

        Assert.Contains(report.Extensions, e => e.Extension == "(none)");
    }

    [Fact]
    public void Scan_ContinuesPastAnUnreadableFileAndRecordsIt()
    {
        // One unreadable file must not abort the scan of an entire installation.
        var fs = ValidInstallation()
            .WithUnreadableFile($"{Root}/locked.dtx")
            .WithFile($"{Root}/sound/ok.wav", new byte[4]);

        var report = Orchestrator(fs).Scan(Root);

        Assert.Equal(3, report.FileCount);
        Assert.Contains("locked.dtx", report.UnreadableFiles.Keys);
    }

    [Fact]
    public void Scan_ReportsAnInvalidInstallationInsteadOfFailing()
    {
        // A near-miss directory should be diagnosable, not merely rejected.
        var fs = new FakeFileSystem().WithFile($"{Root}/readme.txt", new byte[4]);

        var report = Orchestrator(fs).Scan(Root);

        Assert.False(report.IsValidInstallation);
        Assert.Equal(1, report.FileCount);
    }

    [Fact]
    public void Scan_OpensNoFilesWhenProbingIsDisabled()
    {
        var fs = ValidInstallation().WithUnreadableFile($"{Root}/locked.dtx");

        var report = Orchestrator(fs).Scan(Root, new InventoryOptions { ProbeContents = false });

        Assert.Empty(report.UnreadableFiles);
        Assert.Empty(report.Extensions.Single(e => e.Extension == "dtx").Signatures);
    }

    [Fact]
    public void Scan_HonoursCancellation()
    {
        var fs = ValidInstallation();
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        Assert.Throws<OperationCanceledException>(() => Orchestrator(fs).Scan(Root, null, cts.Token));
    }
}
