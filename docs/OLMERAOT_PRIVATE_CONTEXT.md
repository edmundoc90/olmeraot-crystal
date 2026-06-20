# OlmeraOT Private Context

Some OlmeraOT-specific documentation is intentionally not stored in this public repository.

When the private `overrides` submodule is available, read:

```text
overrides/.docs/*
```

That private documentation is the source of truth for OlmeraOT-specific topics such as:

- architecture decisions
- content strategy
- map strategy
- deployment workflows
- release procedures
- rollback procedures
- operational runbooks
- environment topology
- private implementation rules

## Why this is separate

The public repository should remain focused on the CrystalServer-based platform and public-safe project guidance.

Private server-specific strategy, operational details, infrastructure information, and release procedures should live in the private `overrides` repository.

## Guidance for AI agents

If you are an AI coding assistant, agent, or automated tool:

1. Read this public documentation.
2. Check whether `overrides/.docs/` exists.
3. If it exists, read it before proposing OlmeraOT-specific changes.
4. Treat the private documentation as higher priority than generic public documentation.

Do not invent private deployment behavior or operational paths if the private documentation is unavailable.
Instead, ask for the relevant project-specific context.
