// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Core;

/// <summary>
/// Diagnostic log channels. The tags match the conventions in the Technical
/// Design Document, appendix B, so that logs from any subsystem are greppable
/// and comparable across runs.
/// </summary>
public enum LogChannel
{
    /// <summary>Virtual filesystem: mounts, resolution, override precedence.</summary>
    Vfs,

    /// <summary>World loading.</summary>
    Dat,

    /// <summary>Texture decoding.</summary>
    Dtx,

    /// <summary>Model and animation loading.</summary>
    Abc,

    /// <summary>Entity instantiation, including unsupported classes.</summary>
    Entity,

    /// <summary>Deviation from original behaviour beyond an accepted tolerance.</summary>
    Compat,

    /// <summary>Networking and protocol negotiation.</summary>
    Net,
}
