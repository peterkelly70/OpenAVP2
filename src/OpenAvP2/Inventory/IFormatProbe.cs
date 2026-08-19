// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Inventory;

/// <summary>
/// Inspects a single file and reports what can be determined about it.
/// </summary>
/// <remarks>
/// Probes are registered as a collection and offered each file in turn, so that
/// format-specific probes can be added as each format becomes understood
/// (roadmap stages 1 to 7) without changing the orchestrator.
/// </remarks>
public interface IFormatProbe
{
    /// <summary>A stable name identifying this probe in reports.</summary>
    string Name { get; }

    /// <summary>
    /// Whether this probe wants to inspect the given file, judged from its
    /// canonical path alone so that files are not opened unnecessarily.
    /// </summary>
    bool CanProbe(string canonicalPath);

    /// <summary>
    /// Inspects an open, readable stream positioned at the start of the file.
    /// </summary>
    /// <returns>The result, or null when nothing could be determined.</returns>
    ProbeResult? Probe(string canonicalPath, Stream stream);
}
