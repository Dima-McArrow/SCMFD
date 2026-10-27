#!/usr/bin/env python3
"""Generate SCMFD-emotes.md from SCMFD/Commands/Emote.swift.

Usage: python3 tools/gen-emotes-md.py [output.md]   (default: stdout)

The Markdown lists every chat command the iPad can send and ends with a ready
`emotes.txt` block for the Windows server, so both sides stay in sync.
"""

import datetime
import pathlib
import re
import sys

SOURCE = pathlib.Path(__file__).resolve().parent.parent / "SCMFD" / "Commands" / "Emote.swift"

# Matches EmoteGroup("stem"), EmoteGroup("stem", variants: 2), EmoteGroup("stem", title: "T")
# and EmoteGroup("stem", variants: 2, title: "T"), in the argument order of the Swift initializer.
GROUP = re.compile(r'EmoteGroup\("([^"]+)"(?:, variants: (\d+))?(?:, title: "([^"]+)")?\)')


def default_title(stem):
    # Mirrors the Swift fallback: underscores to spaces, then capitalized words.
    return " ".join(word.capitalize() for word in stem.replace("_", " ").split())


def main():
    source = SOURCE.read_text(encoding="utf-8")
    head, _, groups_part = source.partition("var groups")
    category_titles = dict(re.findall(r'case \.(\w+): "([^"]+)"', head))
    categories = re.findall(r"case \.(\w+):\s*\[(.*?)\]", groups_part, re.S)
    if not categories:
        sys.exit("error: no emote categories found in Emote.swift")

    sections, stems, command_count = [], [], 0
    for category, body in categories:
        groups = GROUP.findall(body)
        # Fail loudly instead of silently dropping an emote written in another shape.
        if len(groups) != body.count("EmoteGroup("):
            sys.exit(f"error: unparsed EmoteGroup in category '{category}'")
        if category not in category_titles:
            sys.exit(f"error: no title for category '{category}'")

        sections += [
            f"## {category_titles[category]}\n",
            "| Name | Base command | Variants | All commands |",
            "|---|---|---|---|",
        ]
        for stem, variants, title in groups:
            count = int(variants) if variants else 0
            commands = [f"`/{stem}`"] + [f"`/{stem}{index}`" for index in range(1, count + 1)]
            sections.append(
                f"| {title or default_title(stem)} | `/{stem}` | {count or '—'} | {', '.join(commands)} |"
            )
            stems.append(stem)
            command_count += len(commands)
        sections.append("")

    if len(stems) != len(set(stems)):
        sys.exit("error: duplicate emote stem in Emote.swift")

    lines = [
        "# SCMFD emotes\n",
        f"Generated from `SCMFD/Commands/Emote.swift` ({datetime.date.today().isoformat()}) "
        "by `tools/gen-emotes-md.py`. Source of the commands: starcitizen.tools/Emotes "
        "(command table from 3.7 PTU).\n",
        "## How the iPad sends them\n",
        "- Tapping a tile sends the base command, e.g. `/wave` (the game picks a random variant).",
        "- Numbered chips send a specific variant, e.g. `/wave1`, `/wave2`.",
        "- Every command goes out as a protocol v2 `chat` message: "
        '`{"v":2,"type":"chat","id":"<uuid>","text":"/wave2"}`.',
        "- The server checks `text` against `emotes.txt` (one base name per line; "
        "`/name` and `/name<N>` accepted). A name missing there is rejected.\n",
        f"**Total:** {len(stems)} base names, {command_count} commands.\n",
        *sections,
        "## `emotes.txt` for the Windows server\n",
        "Replace `%LocalAppData%\\CSMFD\\emotes.txt` with this list to match the iPad:\n",
        "```text",
        *stems,
        "```",
    ]
    output = "\n".join(lines) + "\n"

    if len(sys.argv) > 1:
        pathlib.Path(sys.argv[1]).write_text(output, encoding="utf-8")
        print(f"{len(stems)} base names, {command_count} commands -> {sys.argv[1]}", file=sys.stderr)
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
