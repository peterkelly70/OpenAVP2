// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

using System.Text.Json;
using System.Text.Json.Serialization;

namespace OpenAvP2.Inventory;

/// <summary>
/// Writes the inventory as indented JSON.
/// </summary>
/// <remarks>
/// Roadmap stage 0 calls for a machine-readable manifest. JSON keeps the report
/// diffable between runs, so that a patched installation can be compared against
/// an unpatched one.
/// </remarks>
public sealed class JsonInventoryWriter : IInventoryWriter
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    /// <inheritdoc />
    public void Write(InventoryReport report, Stream destination)
    {
        ArgumentNullException.ThrowIfNull(report);
        ArgumentNullException.ThrowIfNull(destination);

        JsonSerializer.Serialize(destination, report, Options);
    }
}
