# Awrad Android — reverse-engineered product specification

This folder documents the current Android application from repository evidence. It is intended to guide product, design, and engineering review before any reconstruction begins.

## Start here

1. [App goal and high-level requirements](goal.md)
2. [Application PRD and feature/module index](prd/PRD.md)
3. [Design tokens and visual language](design.md)
   - [Color system: light and dark palettes](color-system.html)
4. [Technical requirements document](trd/TRD.md)
5. [Flows and diagrams](diagrams/user-flows.md) · [architecture source](diagrams/architecture.architecture.json) · [rendered architecture](diagrams/architecture.html)
6. [Screen mockups](mockups/README.md)
7. [Phase 1 evidence inventory](analysis/phase-1-reconnaissance.md)

## How to read the requirements

- **[OBSERVED]** behavior or constraint found in the current Android implementation, its resources/tests, or a current repository contract.
- **[INFERRED]** product intent that follows from observed behavior but is not explicitly guaranteed by a product owner.
- **[UNKNOWN]** behavior that the source does not settle. Keep it as an open decision instead of silently turning a guess into a requirement.
- **[PROPOSED]** a requirement written to make a reconstruction reviewable; it must be accepted by the product owner where it exceeds the observed implementation.

This is an Android specification. iOS behavior is not assumed to match. The running app and versioned contracts outrank historical Android PRDs where they differ. Feature PRDs describe separately scoped capabilities; module PRDs group their shared user outcomes and boundaries.

## Scope boundary

The docs cover the 35 registered navigation destinations and major local UI surfaces found in the current app. They do not claim that every visible surface is backed by a production service. In particular, Community statistics are API-backed while the social feed and its child screens use demonstrative content/actions. The detailed inventory and unresolved questions are in Phase 1.

