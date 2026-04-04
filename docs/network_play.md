# Network Play Architecture Guide

## Overview
This document outlines the technical development requirements for implementing network play. The networking model relies on a strict server-authoritative architecture without client-side prediction, ensuring that all clients remain perfectly synchronized with the host.

## Connection Protocol
- **Transport Layer**: The game utilizes Godot's high-level multiplayer API (ENet), which operates over **UDP**.
- **Tunneling / Port Forwarding**: Players setting up external access, port forwarding on their routers, or using tunneling tools (like ZeroTier, Hamachi, or Ngrok) must ensure that **UDP** traffic is properly routed to the host.

## Hosting and Joining
- Players can either **Host** a new game or **Join** an existing game.
- To connect, players must specify a host IP address and a port number.
- **Defaults**:
  - **Host IP**: `localhost` (127.0.0.1)
  - **Port**: `7001`

## Lobby System
Once a player has successfully connected to the host, they will enter the game lobby.
- **Scenario Selection**: The lobby will display a list of available factions for the current scenario.
- **Faction Createion and Assignment**: The players must be able to select and join a faction.
  - The lobby will display a list of available factions for the current scenario. Players must be able to select and join a faction.
  - The list of factions is a vertically stacked group of faction slots. Each slot has a color swatch, a faction name, starting money, starting oil, and a button to join the faction.
  - The host may create additional factions if the scenario allows it (there will be an attribute in the scenario setup, "additional-factions: yes" or "additional-factions: no").
  - A button labelled "Add Faction" is clickable by the host if additional factions are allowed.
  - Clicking the "Add Faction" button adds a new faction with the same initial starting resources as the last faction listed in the scenrio.
  - A button labelled "Remove Faction" near the liste faction is clickable by the host if there are more factions than required by the scenario.

- **Game Start Condition**: The game host is only permitted to start the game once a player has successfully joined each of the required factions.

## In-Game Synchronization
- **Event Broadcasting (CRITICAL)**: While the game is in progress, it is absolutely critical that all game events are reliably broadcast from the host to all connected clients.
- **Zero Client Prediction**: 
  - Clients perform **NO** local prediction of game state, physics, or entity movement.
  - The client acts purely as a dumb terminal that renders the state provided by the host and forwards player inputs.
  - All clients must rely entirely on synchronization updates sent by the host to maintain an accurate game state.

## State Communication
To ensure all clients are perfectly synchronized, the following game state elements must be explicitly communicated from the host to the clients:

- **Visible Unit Positions**: The exact coordinates and transforms of all units currently visible to the client.
- **Unit Movement and Status**: Movement orders, pathing updates, and current status effects (e.g., entrenched, moving, defending) for all relevant units.
- **Combat Events**: Damage inflicted during engagements, units destroyed, and visual/audio cues for combat actions.
- **Territory Control**: The capture or loss of cities and other strategic locations.
- **Resource Management (Fuel)**: The accumulation, current reserves, and expenditure of fuel for each faction.
- **Resource Management (Money)**: The accumulation, current treasury, and expenditure of money for each faction.
- **Game Resolution**: End-of-game events, including win/loss conditions triggering and final statistics.

## Faction control
- Players with a faction can control only the units of their faction. Interacting with units of another faction does nothing.

## Limited Visibility
- Players can only see units that are within their detection range.
- Land units and cities detect other units within (unit width * 3) distance. 