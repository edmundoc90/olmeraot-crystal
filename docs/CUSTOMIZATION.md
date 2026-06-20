# OlmeraOT Customization Policy

OlmeraOT is based on CrystalServer and should remain easy to update from upstream.

The project follows a strict separation between platform and custom content:

```text
CrystalServer = platform
Overrides     = OlmeraOT identity
```

## Preferred customization flow

Whenever possible:

1. Implement custom content in the private `overrides/` submodule.
2. Use configuration when a behavior can be configured safely.
3. Use modular map additions or overlays when changing map content.
4. Modify CrystalServer core only as a last resort.

## New custom content

New server-specific content should not be added directly to the public CrystalServer tree unless there is a clear reason.

Examples of content that normally belongs in `overrides/`:

- custom monsters
- custom NPCs
- custom quests
- custom scripts
- custom actions
- custom talkactions
- custom movements
- custom events
- custom systems
- custom map additions
- server-specific balancing

## Existing upstream content

Avoid modifying upstream files directly when possible.

If OlmeraOT needs to customize existing upstream content, prefer an override-based approach so future upstream merges remain manageable.

When an upstream file and an OlmeraOT override both change, review whether:

- the override is still required
- upstream already fixed the issue
- the override should be updated
- the override can be removed

## Engine changes

Changes under engine/build/infrastructure areas should be considered higher risk.

Modify CrystalServer core only when:

- fixing an engine bug
- adding a required engine capability
- no override or configuration solution exists

Always prefer the least invasive approach that preserves future upstream compatibility.
