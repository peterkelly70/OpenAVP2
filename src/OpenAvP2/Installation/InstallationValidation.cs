// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Installation;

/// <summary>
/// One checked expectation about a candidate installation directory, shown on
/// the first-run screen described in the Technical Design Document, section 6.
/// </summary>
/// <param name="Requirement">What was checked, in words a user can act on.</param>
/// <param name="Satisfied">Whether the requirement was met.</param>
/// <param name="Detail">Supporting detail, such as the file that was or was not found.</param>
public sealed record InstallationCheck(string Requirement, bool Satisfied, string Detail);

/// <summary>
/// The outcome of validating a candidate AvP2 installation directory.
/// </summary>
/// <param name="Path">The directory that was validated.</param>
/// <param name="IsValid">Whether the directory can be used as a game installation.</param>
/// <param name="Checks">Every check performed, satisfied or not, in display order.</param>
public sealed record InstallationValidation(
    string Path,
    bool IsValid,
    IReadOnlyList<InstallationCheck> Checks)
{
    /// <summary>Checks that failed. Empty when <see cref="IsValid"/> is true.</summary>
    public IEnumerable<InstallationCheck> Failures => Checks.Where(c => !c.Satisfied);
}
