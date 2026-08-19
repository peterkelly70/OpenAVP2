// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Installation;

/// <summary>
/// Decides whether a directory is a usable AvP2 installation
/// (Technical Design Document, section 6).
/// </summary>
public interface IInstallationValidator
{
    /// <summary>
    /// Validates a candidate directory, reporting every check performed so that
    /// a user can see what is missing rather than only that validation failed.
    /// </summary>
    InstallationValidation Validate(string path);
}
