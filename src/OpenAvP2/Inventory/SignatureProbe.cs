// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Inventory;

/// <summary>
/// Records the leading bytes of every file, without interpreting them.
/// </summary>
/// <remarks>
/// This is the probe that makes roadmap stage 0 possible before any format is
/// documented. Rather than assuming magic numbers and version offsets, it groups
/// the files in a real installation by their observed leading bytes, so that the
/// number of distinct variants of each format becomes an observation instead of
/// an assumption. The resulting signatures are the starting point for the format
/// notes in <c>docs/formats/</c>.
/// </remarks>
public sealed class SignatureProbe : IFormatProbe
{
    /// <summary>Number of leading bytes recorded from each file.</summary>
    public const int SignatureLength = 16;

    private static readonly IReadOnlyDictionary<string, string> NoFacts =
        new Dictionary<string, string>();

    /// <inheritdoc />
    public string Name => "signature";

    /// <inheritdoc />
    public bool CanProbe(string canonicalPath) => true;

    /// <inheritdoc />
    public ProbeResult? Probe(string canonicalPath, Stream stream)
    {
        ArgumentNullException.ThrowIfNull(stream);

        Span<byte> buffer = stackalloc byte[SignatureLength];
        var read = stream.ReadAtLeast(buffer, SignatureLength, throwOnEndOfStream: false);

        return read == 0
            ? null
            : new ProbeResult(Name, Convert.ToHexString(buffer[..read]), NoFacts);
    }
}
