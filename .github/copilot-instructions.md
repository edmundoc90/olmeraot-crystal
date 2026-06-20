# Copilot Instructions

Before making OlmeraOT-specific changes, first check whether the private `overrides` submodule is available.

If it is available, read:

```text
overrides/.docs/*
```

The private documentation is the source of truth for OlmeraOT-specific decisions, including:

- architecture
- content strategy
- deployment strategy
- release process
- rollback rules
- map strategy
- operational workflows

Do not rely only on generic CrystalServer documentation when working on OlmeraOT-specific changes.

## Public-safe rules

- Prefer `overrides/` over CrystalServer core modifications.
- Preserve compatibility with CrystalServer upstream.
- Do not edit generated `config.lua` files directly.
- Prefer modular map additions or overlays over direct base-map replacement.
- Minimize future merge conflicts with upstream CrystalServer.
- Keep private server-specific content outside the public repository.
- Do not add secrets, credentials, private paths, private ports, private infrastructure details, or production operational notes to the public repository.

## Decision order

When implementing custom behavior, prefer this order:

1. Private `overrides/` content.
2. Configuration.
3. Modular map overlays or custom map additions.
4. CrystalServer engine modifications only when strictly necessary.

## Required Reading

Before modifying CI/CD, deployment scripts, releases, rollback logic, or environment configuration, read:

- .docs/08_CI_CD_ARCHITECTURE.md
- .docs/05_DEPLOYMENT.md
- .docs/06_RELEASES_AND_ROLLBACK.md
- .docs/07_DEVELOPMENT_WORKFLOW.md
- .docs/15_OPS_SCRIPT_INSTALLATION.md
