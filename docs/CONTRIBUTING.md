# Contributing to OlmeraOT

OlmeraOT is a CrystalServer-based project with a strong preference for maintainability and upstream compatibility.

## General principles

Contributions should prioritize:

- stability
- clarity
- reproducibility
- upstream compatibility
- minimal operational risk

Avoid unnecessary changes to CrystalServer core files.

## Upstream compatibility

This repository may receive future changes from CrystalServer upstream.

Contributors should:

- minimize future merge conflicts
- avoid large unrelated refactors
- keep custom server identity outside the public repository when possible
- preserve clean separation between platform code and private content

## Custom content

OlmeraOT custom content should normally live in the private `overrides/` submodule.

If the submodule is available locally, read its documentation before making OlmeraOT-specific changes:

```text
overrides/.docs/*
```

The private documentation may contain the current project-specific architecture, deployment process, release process, rollback rules, and content strategy.

## Public repository safety

Do not commit:

- secrets
- credentials
- production database passwords
- private operational notes
- private infrastructure details
- environment-specific private configuration
- generated local configuration files

Generated files such as `config.lua` should not be edited directly unless the project-specific documentation explicitly says otherwise.

## Pull request expectations

Before proposing a change, consider:

1. Can this be implemented in `overrides/`?
2. Can this be implemented through configuration?
3. Can this be implemented as a modular map addition?
4. Is a CrystalServer engine change truly required?

For engine changes, explain why an override or configuration solution is not enough.
