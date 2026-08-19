// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Peter Kelly and the OpenAvP2 contributors

// Headless dedicated server entry point. No renderer, no audio stack, no GUI
// dependency (Technical Design Document, section 15).
//
//   openavp2-server --map dm_alley --port 27888 --players 16
//
// Not implemented: the server is scheduled for roadmap stage 18 and depends on
// the world, entity and gameplay layers landing first.

Console.Error.WriteLine("openavp2-server is not implemented yet (roadmap stage 18).");
return 1;
