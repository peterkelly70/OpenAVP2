// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using System.Text;
using System.Text.Json;
using OpenAvP2.Inventory;
using Xunit;

namespace OpenAvP2.Tests.Installation;

public class JsonInventoryWriterTests
{
    private static InventoryReport SampleReport() => new(
        InstallationPath: "/games/avp2",
        GeneratedUtc: DateTimeOffset.UnixEpoch,
        ToolVersion: "0.0.1",
        IsValidInstallation: true,
        FileCount: 2,
        TotalBytes: 1024,
        Extensions: [new ExtensionSummary("rez", 1, 512, [new SignatureGroup("52657A4D", 1, ["avp2.rez"])])],
        UnreadableFiles: new Dictionary<string, string> { ["locked.dtx"] = "denied" });

    [Fact]
    public void Write_ProducesParseableCamelCaseJson()
    {
        using var stream = new MemoryStream();

        new JsonInventoryWriter().Write(SampleReport(), stream);

        using var document = JsonDocument.Parse(Encoding.UTF8.GetString(stream.ToArray()));
        var root = document.RootElement;

        Assert.Equal("/games/avp2", root.GetProperty("installationPath").GetString());
        Assert.Equal(2, root.GetProperty("fileCount").GetInt32());
        Assert.True(root.GetProperty("isValidInstallation").GetBoolean());
    }

    [Fact]
    public void Write_PreservesSignatureDetail()
    {
        using var stream = new MemoryStream();

        new JsonInventoryWriter().Write(SampleReport(), stream);

        using var document = JsonDocument.Parse(Encoding.UTF8.GetString(stream.ToArray()));
        var signature = document.RootElement
            .GetProperty("extensions")[0]
            .GetProperty("signatures")[0];

        Assert.Equal("52657A4D", signature.GetProperty("signature").GetString());
        Assert.Equal("avp2.rez", signature.GetProperty("examples")[0].GetString());
    }

    [Fact]
    public void Write_IncludesUnreadableFilesSoScansAreDiagnosable()
    {
        using var stream = new MemoryStream();

        new JsonInventoryWriter().Write(SampleReport(), stream);

        using var document = JsonDocument.Parse(Encoding.UTF8.GetString(stream.ToArray()));

        Assert.Equal("denied",
            document.RootElement.GetProperty("unreadableFiles").GetProperty("locked.dtx").GetString());
    }
}
