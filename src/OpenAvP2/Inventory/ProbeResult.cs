// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Inventory;

/// <summary>
/// What a probe determined about one file.
/// </summary>
/// <param name="ProbeName">The probe that produced this result.</param>
/// <param name="Signature">
/// The file's leading bytes as uppercase hex, used to group files by variant
/// before any format is documented.
/// </param>
/// <param name="Facts">
/// Named observations, such as a format version once the relevant format is
/// understood. Empty until a format-specific probe exists.
/// </param>
public sealed record ProbeResult(
    string ProbeName,
    string Signature,
    IReadOnlyDictionary<string, string> Facts);
