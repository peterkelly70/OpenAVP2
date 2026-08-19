// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Inventory;

/// <summary>One distinct leading-byte signature observed for an extension.</summary>
/// <param name="Signature">The leading bytes as uppercase hex.</param>
/// <param name="Count">How many files share this signature.</param>
/// <param name="Examples">A few example paths, for looking the variant up by hand.</param>
public sealed record SignatureGroup(string Signature, int Count, IReadOnlyList<string> Examples);

/// <summary>Everything observed about one file extension in an installation.</summary>
/// <param name="Extension">The lowercased extension without its dot, or "(none)".</param>
/// <param name="Count">Number of files with this extension.</param>
/// <param name="TotalBytes">Combined size of those files.</param>
/// <param name="Signatures">Distinct leading-byte signatures, most common first.</param>
public sealed record ExtensionSummary(
    string Extension,
    int Count,
    long TotalBytes,
    IReadOnlyList<SignatureGroup> Signatures);

/// <summary>
/// The machine-readable manifest of one AvP2 installation, which is the exit
/// criterion for roadmap stage 0.
/// </summary>
/// <param name="InstallationPath">The directory that was scanned.</param>
/// <param name="GeneratedUtc">When the scan ran.</param>
/// <param name="ToolVersion">Version of the tool, so reports can be compared across changes.</param>
/// <param name="IsValidInstallation">Whether the directory validated as an AvP2 installation.</param>
/// <param name="FileCount">Total files scanned.</param>
/// <param name="TotalBytes">Combined size of all files scanned.</param>
/// <param name="Extensions">Per-extension summaries, largest file count first.</param>
/// <param name="UnreadableFiles">Files that could not be opened, with the reason.</param>
public sealed record InventoryReport(
    string InstallationPath,
    DateTimeOffset GeneratedUtc,
    string ToolVersion,
    bool IsValidInstallation,
    int FileCount,
    long TotalBytes,
    IReadOnlyList<ExtensionSummary> Extensions,
    IReadOnlyDictionary<string, string> UnreadableFiles);
