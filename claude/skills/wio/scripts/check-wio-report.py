#!/usr/bin/env python3
"""Check that a saved WIO report contains the expected mode markers."""

from __future__ import annotations

import argparse
import re
import sys


MODE_MARKERS = {
    "scan": ["Scope And Evidence", "Ranked Candidates", "Best Next Test"],
    "test": ["Candidate", "Strategy", "Changes", "Validation", "Review", "Remaining Risk"],
    "workload": ["Workload", "Coverage", "Variance And Replay", "Implementation And Validation"],
    "review": ["Verdict:", "Protected behavior:", "Value:", "Signal strengths:", "False-confidence risks:", "Required action:"],
    "doctor": ["Scope And Evidence", "Overall", "Top Concerns", "Rubric"],
}


def read_input(path: str | None) -> str:
    if path:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    return sys.stdin.read()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate that a saved WIO markdown report follows the expected output skeleton."
    )
    parser.add_argument("mode", choices=sorted(MODE_MARKERS))
    parser.add_argument("path", nargs="?", help="Markdown report path. Reads stdin when omitted.")
    args = parser.parse_args()

    text = read_input(args.path)
    missing = [marker for marker in MODE_MARKERS[args.mode] if marker not in text]

    if args.mode in {"test", "review"}:
        verdicts = re.findall(r"\b(KEEP|REDO|REMOVE)\b", text)
        if not verdicts:
            missing.append("KEEP|REDO|REMOVE verdict")

    if missing:
        for marker in missing:
            print(f"missing: {marker}", file=sys.stderr)
        return 2

    print("ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
