# README template

Use this exact section order for every active project README. Keep each README focused on its component; put long procedures and technical research in dedicated guides.

# {Component name}

## Overview

One concise paragraph describing the component, purpose and boundaries.

## Status

State what is implemented, published and untested. Distinguish source validation, compilation, artifact checks, QEMU boot, graphical startup and physical hardware verification.

## Layout

List only important paths and explain their roles.

## Requirements

List target hardware, host tools, dependencies, permissions, storage and boot constraints.

## Use

Present the recommended workflow first. Link detailed installation, operation and recovery procedures to a user guide. State persistence and rollback behavior.

## Build

Link the canonical workflow and local builder. Explain important inputs and output paths. Do not imply that an unrelated workflow builds this component.

## Releases

Link the relevant release and repository-wide release index. Identify matching artifact sets and checksums; do not use ambiguous latest references when a pinned tag is required.

## Validation

List the exact checks that apply and what they prove. Never label static validation as compilation, boot or physical-hardware testing.

## Related documentation

Link authoritative adjacent user guides, technical references, hardware notes, known issues and the release index.

### Style

- Use exactly one H1 title and the nine H2 sections above in the same order. H3 subsections are allowed inside a section; do not add another H2.
- Write for human users: direct language, short paragraphs, consistent terminology and descriptive link labels.
- Prefer relative repository links. Use fenced code blocks with language tags for commands and configuration.
- Use tables for compact status or comparison data; use short, parallel bullets for inventories.
- Keep the root README an index, not a runbook. Keep component READMEs focused on their component.
- Put detailed command sequences in user guides, hardware research in technical guides and obsolete plans in the archive.
- State test scope precisely. Do not claim that a source check proves a build, that QEMU proves physical hardware, or that a browser feature flag proves actual media decoding.
- Avoid badges, decorative ASCII art, excessive headings, raw log dumps, repeated configuration and filler text.
- Keep the README human-facing. Do not add AI instructions, credentials, internal runner secrets or agent-only procedures.
