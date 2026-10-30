# README template

Use this exact section order for every active project `README.md`. Keep each README focused on the named component; put lengthy step-by-step procedures in a dedicated guide and link to it.

# {Component name}

## Overview

One paragraph describing the component, purpose and boundaries.

## Status

State what is implemented, what is published, and what remains untested. Distinguish static checks, build completion, QEMU boot, graphical startup and physical hardware verification.

## Layout

List the important component paths and explain their roles.

## Requirements

List target hardware, host tools, dependencies, permissions, storage and boot constraints. Use “Not applicable” only when appropriate.

## Use

Present the recommended user workflow first. Link detailed installation, operation and recovery steps to a separate guide. State persistence and rollback behavior.

## Build

Link the canonical workflow and local builder. Explain important inputs and output paths. Do not imply that an unrelated workflow builds this component.

## Releases

Link the current release and the repository-wide release index. Identify matching artifact sets and checksums.

## Validation

List the exact checks that apply and what they prove. Never label static validation as a build or boot test.

## Related documentation

Link authoritative adjacent guides, hardware notes, known issues, release index and component-specific agent rules.
