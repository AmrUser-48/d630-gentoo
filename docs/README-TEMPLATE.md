# README guidance

README files are navigation and orientation documents, not forms to fill in. Keep each README focused on its component. Put long procedures in user guides, technical research in dedicated references, and historical material in the archive.

## Recommended structure

Use only the sections that provide useful information for that component. A sensible order, when the sections apply, is:

1. **Overview** — purpose and boundaries.
2. **Status** — implemented, published and untested work; distinguish source checks, builds, artifact verification, QEMU and physical-hardware testing.
3. **Layout** — important paths and their roles.
4. **Requirements** — target hardware, host tools, dependencies, permissions and boot/storage constraints.
5. **Use** — the normal user workflow, persistence and rollback.
6. **Build** — canonical workflow, local builder, important inputs and outputs.
7. **Releases** — matching artifacts, exact tags and checksums.
8. **Validation** — checks and what each one proves.
9. **Related documentation** — user guides, hardware notes, technical references, known issues and release index.

Do not add a section just to preserve this list. Omit inapplicable sections instead of writing "Not applicable". Use purpose-specific headings when they make the document clearer. When several recommended sections are present, keep them in the order above.

## Style

- Use one descriptive H1 title. Use H2 for major topics and H3 or lower for genuine subsections.
- Write for people using or maintaining the project: direct language, short paragraphs and consistent terminology.
- Prefer relative repository links and descriptive link labels.
- Use fenced code blocks with language tags for commands and configuration.
- Use tables for compact status or comparison data; use short, parallel bullets for inventories.
- Keep the root README an index, not a runbook. Keep component READMEs focused on their component.
- Put detailed command sequences in user guides, hardware research in technical guides and obsolete plans in the archive.
- State test scope precisely. A source check does not prove a build; QEMU does not prove physical hardware; a browser feature flag does not prove actual media decoding.
- Avoid badges, decorative ASCII art, excessive headings, raw log dumps, repeated configuration, duplicate summaries and filler.
- Keep README files human-facing. Do not add AI instructions, credentials, runner secrets or agent-only procedures.

## Automated checks

Run `python3 scripts/validate-readmes.py` from the repository root. The validator discovers tracked `README.md` files and checks:

- exactly one H1 document title;
- duplicate headings at the same level and empty sections;
- balanced fenced code blocks;
- order of canonical sections when those headings are used;
- existence of relative/local Markdown link targets.

It does **not** require every README to contain all nine recommended sections, enforce identical section counts, or reject purpose-specific headings. Its purpose is to catch navigation and markup defects without creating boilerplate.
