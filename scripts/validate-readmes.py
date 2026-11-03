#!/usr/bin/env python3
"""Content-aware validation for tracked repository README.md files.

The README template is guidance, not a form: canonical sections are optional.
"""
from __future__ import annotations

import html
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

CANONICAL_H2_ORDER = (
    "overview", "status", "layout", "requirements", "use",
    "build", "releases", "validation", "related documentation",
)
FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
HEADING_RE = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")
INLINE_LINK_RE = re.compile(r"!?(?:\[[^\]]*\])\(\s*(<[^>]+>|[^)\s]+)")
REFERENCE_DEF_RE = re.compile(r"^ {0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)")
INLINE_CODE_RE = re.compile(r"`+.*?`+")


def tracked_readmes() -> list[str]:
    """Discover every tracked README.md, including nested component READMEs."""
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        paths = [
            item.decode("utf-8", "surrogateescape")
            for item in result.stdout.split(b"\0") if item
        ]
    except (OSError, subprocess.CalledProcessError):
        excluded = {".git", "node_modules", ".venv", "venv", "output"}
        paths = [
            item.as_posix() for item in Path(".").rglob("README.md")
            if not (set(item.parts) & excluded)
        ]
    return sorted(
        item for item in paths
        if PurePosixPath(item).name.lower() == "readme.md" and Path(item).is_file()
    )


def normal_heading(value: str) -> str:
    return " ".join(value.casefold().split())


def inspect_readme(path: str, source: str, errors: list[str]) -> tuple[int, int]:
    lines = source.splitlines()
    headings: list[dict] = []
    links: list[tuple[int, str]] = []
    fence: tuple[str, int, int] | None = None

    for number, line in enumerate(lines, 1):
        fence_match = FENCE_RE.match(line)
        if fence_match:
            marker = fence_match.group(1)
            tail = fence_match.group(2)
            if fence is None:
                if marker[0] == "`" and "`" in tail:
                    errors.append(
                        f"{path}:{number}: backticks are not allowed in a fenced-code info string"
                    )
                else:
                    fence = (marker[0], len(marker), number)
            elif marker[0] == fence[0] and len(marker) >= fence[1] and not tail.strip():
                fence = None
            continue
        if fence is not None:
            continue

        heading_match = HEADING_RE.match(line)
        if heading_match:
            title = heading_match.group(2).strip()
            if not title:
                errors.append(f"{path}:{number}: empty Markdown heading")
            else:
                headings.append({
                    "level": len(heading_match.group(1)),
                    "title": title,
                    "line": number,
                })

        # Do not treat inline-code examples as Markdown links.
        visible = INLINE_CODE_RE.sub("", line)
        links.extend((number, match.group(1)) for match in INLINE_LINK_RE.finditer(visible))
        definition = REFERENCE_DEF_RE.match(visible)
        if definition:
            links.append((number, definition.group(1)))

    if fence is not None:
        errors.append(
            f"{path}:{fence[2]}: unclosed {fence[0] * fence[1]} code fence"
        )

    titles = [heading for heading in headings if heading["level"] == 1]
    if len(titles) != 1:
        found = ", ".join(str(item["line"]) for item in titles) or "none"
        errors.append(
            f"{path}: expected exactly one H1 document title; found {len(titles)} ({found})"
        )

    # Duplicate H2 sections usually indicate pasted/repeated content.
    # Repeated H3+ subsection names are allowed; they can be useful under
    # different parent sections and GitHub assigns distinct heading anchors.
    seen_h2: dict[str, int] = {}
    for heading in headings:
        if heading["level"] != 2:
            continue
        key = normal_heading(heading["title"])
        if key in seen_h2:
            errors.append(
                f"{path}:{heading['line']}: duplicate H2 section "
                f"{heading['title']!r}; first occurrence is line {seen_h2[key]}"
            )
        else:
            seen_h2[key] = heading["line"]

    # Canonical sections are optional. If a README uses any of them, keep the
    # ones it uses in the recommended order; purpose-specific headings are free.
    order = {name: index for index, name in enumerate(CANONICAL_H2_ORDER)}
    previous = -1
    previous_title = None
    for heading in headings:
        key = normal_heading(heading["title"])
        if heading["level"] != 2 or key not in order:
            continue
        current = order[key]
        if current < previous:
            errors.append(
                f"{path}:{heading['line']}: {heading['title']!r} is after "
                f"{previous_title!r}; reorder the canonical sections that are present"
            )
        previous, previous_title = current, heading["title"]

    # Catch empty headings/sections without requiring every possible section.
    for index, heading in enumerate(headings):
        if heading["level"] == 1:
            continue
        end = len(lines)
        for following in headings[index + 1:]:
            if following["level"] <= heading["level"]:
                end = following["line"] - 1
                break
        body = lines[heading["line"]:end]
        has_content = any(
            item.strip()
            and not re.match(r"^ {0,3}#{1,6}[ \t]+", item)
            and not item.strip().startswith("<!--")
            and not item.strip().endswith("-->")
            for item in body
        )
        if not has_content:
            errors.append(
                f"{path}:{heading['line']}: H{heading['level']} section "
                f"{heading['title']!r} has no content"
            )

    checked_links = 0
    for number, raw_target in links:
        target = raw_target[1:-1] if raw_target.startswith("<") and raw_target.endswith(">") else raw_target
        target = html.unescape(re.sub(r"\\(.)", r"\1", target))
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc or target.startswith("//"):
            continue

        relative_path = unquote(parsed.path)
        if not relative_path:
            resolved = path
        elif relative_path.startswith("/"):
            resolved = os.path.normpath(relative_path.lstrip("/"))
        else:
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), relative_path))

        if not os.path.exists(resolved):
            errors.append(
                f"{path}:{number}: broken local link {raw_target!r} "
                f"(resolved to {resolved})"
            )
        checked_links += 1

    return len(headings), checked_links


def main() -> int:
    files = tracked_readmes()
    if not files:
        print("README validation: no tracked README.md files found", file=sys.stderr)
        return 1

    errors: list[str] = []
    heading_count = 0
    link_count = 0
    for path in files:
        source = Path(path).read_text(encoding="utf-8")
        headings, links = inspect_readme(path, source, errors)
        heading_count += headings
        link_count += links

    if errors:
        print(f"README validation failed ({len(errors)} issue(s)):", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(
        f"README validation passed: {len(files)} files, {heading_count} headings, "
        f"{link_count} local links. Optional sections are not required."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
