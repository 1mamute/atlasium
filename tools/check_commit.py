"""Check a PR title or commit subject against the project's commit convention."""

import os
import re
import sys

PATTERN = re.compile(
    r"(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)"
    r": [^\s].*"
)


def is_valid_subject(subject):
    return "\n" not in subject and "\r" not in subject and PATTERN.fullmatch(subject) is not None


if __name__ == "__main__":
    subject = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PR_TITLE", "")
    if not is_valid_subject(subject):
        sys.exit("Use type: description without a scope, for example: feat: add map notes")
    print("Commit title is valid.")
