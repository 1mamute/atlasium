"""Check a PR title or commit subject against the project's commit convention."""

import os
import re
import sys

PATTERN = re.compile(
    r"(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)"
    r"(?:\([^()\s]+\))?!?: [^\s].*"
)


def is_conventional(subject):
    return "\n" not in subject and PATTERN.fullmatch(subject) is not None


if __name__ == "__main__":
    subject = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PR_TITLE", "")
    if not is_conventional(subject):
        sys.exit("Use a Conventional Commit title, for example: feat(map): add map notes")
    print("Conventional Commit title is valid.")
