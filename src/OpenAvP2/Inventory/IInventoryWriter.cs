// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

namespace OpenAvP2.Inventory;

/// <summary>Serialises an inventory report.</summary>
public interface IInventoryWriter
{
    /// <summary>Writes a report to a stream.</summary>
    void Write(InventoryReport report, Stream destination);
}
