// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Gameplay;

/// <summary>
/// Boundary between engine-level compatibility work and game-specific rules
/// (Technical Design Document, section 18).
/// </summary>
/// <remarks>
/// The interface exists from the start so that base-game architecture does not
/// become impossible to extend, but Primal Hunt is not implemented until the
/// base game is stable. Selection is explicit: <c>openavp2 --game avp2</c>.
/// </remarks>
public interface IGameModule
{
    /// <summary>Identifier used by the <c>--game</c> command line option.</summary>
    string Id { get; }

    /// <summary>Human-readable title shown in the launcher and diagnostics.</summary>
    string DisplayName { get; }

    /// <summary>
    /// Archives this module requires from the installation, as canonical VFS
    /// paths, used to validate the selected installation directory.
    /// </summary>
    IReadOnlyList<string> RequiredArchives { get; }
}
