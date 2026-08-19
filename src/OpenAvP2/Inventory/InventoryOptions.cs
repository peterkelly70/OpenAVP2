// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Inventory;

/// <summary>Options controlling an inventory scan.</summary>
public sealed record InventoryOptions
{
    /// <summary>
    /// Maximum number of example paths recorded per signature group. Keeps the
    /// report readable on an installation with tens of thousands of files.
    /// </summary>
    public int ExamplesPerSignature { get; init; } = 3;

    /// <summary>
    /// Whether to open files to read their signatures. When false the scan
    /// reports only names and sizes, which is fast and touches no file contents.
    /// </summary>
    public bool ProbeContents { get; init; } = true;
}
