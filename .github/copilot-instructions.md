# Copilot Instructions

Before making OlmeraOT-specific changes, read the private documentation in:

`overrides/.docs/*`

The private `overrides` submodule is the source of truth for:

- OlmeraOT architecture
- content strategy
- deployment strategy
- release process
- rollback rules
- map strategy

Do not rely only on public CrystalServer documentation for OlmeraOT-specific decisions.

Important public-safe rules:

- Prefer `overrides/` for OlmeraOT custom content.
- Do not edit generated `config.lua` files.
- Avoid modifying CrystalServer core unless strictly necessary.
- Preserve upstream compatibility.
- Prefer modular map additions over direct `world.otbm` changes.
