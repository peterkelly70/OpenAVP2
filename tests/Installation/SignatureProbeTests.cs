// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using System.Text;
using OpenAvP2.Inventory;
using Xunit;

namespace OpenAvP2.Tests.Installation;

public class SignatureProbeTests
{
    private static readonly SignatureProbe Probe = new();

    [Fact]
    public void Probe_RecordsTheLeadingBytesAsHex()
    {
        using var stream = new MemoryStream(Encoding.ASCII.GetBytes("RezMgr Version 1"));

        var result = Probe.Probe("avp2.rez", stream);

        Assert.NotNull(result);
        Assert.Equal(Convert.ToHexString(Encoding.ASCII.GetBytes("RezMgr Version 1")), result.Signature);
    }

    [Fact]
    public void Probe_TruncatesToTheSignatureLength()
    {
        using var stream = new MemoryStream(new byte[SignatureProbe.SignatureLength * 4]);

        var result = Probe.Probe("big.dat", stream);

        Assert.NotNull(result);
        Assert.Equal(SignatureProbe.SignatureLength * 2, result.Signature.Length);
    }

    [Fact]
    public void Probe_HandlesAFileShorterThanTheSignatureLength()
    {
        using var stream = new MemoryStream([0xDE, 0xAD]);

        var result = Probe.Probe("tiny.dat", stream);

        Assert.NotNull(result);
        Assert.Equal("DEAD", result.Signature);
    }

    [Fact]
    public void Probe_ReturnsNullForAnEmptyFile()
    {
        using var stream = new MemoryStream();

        Assert.Null(Probe.Probe("empty.dat", stream));
    }

    [Fact]
    public void Probe_AcceptsEveryFileBecauseNoFormatIsAssumed()
    {
        Assert.True(Probe.CanProbe("anything.xyz"));
        Assert.True(Probe.CanProbe("no-extension"));
    }
}
