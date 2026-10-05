"""Build the player distribution from the TOC manifest and Markdown docs."""

import argparse
import hashlib
from pathlib import Path
import re
import zipfile
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(
    r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
    r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
    r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
)


def release_files(root, tag):
    if not tag.startswith("v") or not SEMVER.fullmatch(tag[1:]):
        raise ValueError("Tag must be v followed by a SemVer version, for example v1.0.0")
    toc = root / "Atlasium/Atlasium.toc"
    text = toc.read_text(encoding="utf-8-sig")
    version = re.search(r"^## Version:\s*(\S+)\s*$", text, re.MULTILINE)
    if not version or version.group(1) != tag[1:]:
        raise ValueError("Tag does not match the Version field in Atlasium.toc")
    files = {toc, root / "README.md", root / "CHANGELOG.md", root / "LICENSE"}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        path = (root / "Atlasium" / line.replace("\\", "/")).resolve()
        if not path.is_relative_to((root / "Atlasium").resolve()):
            raise ValueError("TOC entry leaves the add-on directory")
        files.add(path)
    for language in ("en-US", "pt-BR"):
        files.update(path for path in (root / "docs" / language).rglob("*.md")
                     if "contributing" not in path.relative_to(root / "docs").parts)
    for path in files:
        if not path.is_file():
            raise ValueError(f"Required release file is missing: {path}")
    return sorted(files, key=lambda path: path.relative_to(root).as_posix())


def release_notes(root, tag):
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    section = re.search(
        rf"^## \[{re.escape(tag[1:])}\][^\n]*\n(.*?)(?=^## |\Z)",
        changelog, re.MULTILINE | re.DOTALL,
    )
    if not section:
        raise ValueError("CHANGELOG.md needs a section for the release version")
    return section.group(1).strip() + "\n"


def build_release(root, tag, output):
    files = release_files(root, tag)
    notes = release_notes(root, tag)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"Atlasium-{tag}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for path in files:
            # Fixed metadata makes the ZIP reproducible across machines and reruns.
            entry = zipfile.ZipInfo(path.relative_to(root).as_posix(), (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            content = path.read_bytes()
            if path.suffix == ".md":
                content = distribution_markdown(path, files, root, tag).encode("utf-8")
            bundle.writestr(entry, content)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    (output / "notes.md").write_text(notes, encoding="utf-8")
    return archive


def distribution_markdown(path, files, root, tag):
    """Keep links to excluded images and contributor docs usable on GitHub."""
    included = {file.resolve() for file in files}

    def rewrite(match):
        href = match.group(0)
        url = urlsplit(href)
        if url.scheme or url.netloc or not url.path:
            return href
        target = (path.parent / unquote(url.path)).resolve()
        if target in included or not target.is_relative_to(root.resolve()) or not target.is_file():
            return href
        suffix = "#" + url.fragment if url.fragment else ""
        return f"https://github.com/1mamute/atlasium/blob/{tag}/{target.relative_to(root).as_posix()}{suffix}"

    text = path.read_text(encoding="utf-8")
    text = re.sub(r"(?<=\]\()([^\s)]+)", rewrite, text)
    return re.sub(r'(?<=src=")([^"\s]+)', rewrite, text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / ".build/release")
    args = parser.parse_args()
    try:
        print(build_release(ROOT, args.tag, args.output))
    except ValueError as error:
        parser.error(str(error))
