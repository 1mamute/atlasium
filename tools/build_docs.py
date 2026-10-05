"""Build the bilingual documentation with Doxygen and the approved static HTML theme."""

import argparse
from html import escape
from html.parser import HTMLParser
import posixpath
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("en-US", "pt-BR")
LABELS = {
    "en-US": {
        "skip": "Skip to content", "languageLabel": "Documentation language", "darkMode": "Dark mode",
        "documentation": "Documentation", "onPage": "ON THIS PAGE", "start": "GET STARTED",
        "explore": "EXPLORE", "contribute": "CONTRIBUTE", "home": "Overview",
        "description": "Atlasium documentation for World of Warcraft 3.3.5a.",
    },
    "pt-BR": {
        "skip": "Ir para o conteúdo", "languageLabel": "Idioma da documentação", "darkMode": "Modo escuro",
        "documentation": "Documentação", "onPage": "NESTA PÁGINA", "start": "PRIMEIROS PASSOS",
        "explore": "EXPLORE", "contribute": "CONTRIBUA", "home": "Visão geral",
        "description": "Documentação do Atlasium para World of Warcraft 3.3.5a.",
    },
}
GROUPS = (
    ("start", ("README.md", "docs/installation.md", "docs/usage.md", "docs/configuration.md")),
    ("explore", ("docs/features.md", "docs/party.md")),
    ("contribute", ("docs/contributing/README.md", "docs/contributing/architecture.md",
                    "docs/contributing/testing.md", "docs/contributing/development.md",
                    "docs/contributing/in-game-testing.md", "docs/contributing/conventions.md",
                    "docs/contributing/documentation.md", "docs/contributing/releases.md")),
)


def headings(text):
    """Get headings outside code fences, with GitHub-style stable section IDs."""
    result, counts, fence = [], {}, None
    for line in text.splitlines():
        delimiter = re.match(r"\s*(`{3,}|~{3,})", line)
        if delimiter:
            marker = delimiter[1][0]
            if fence == marker:
                fence = None
            elif fence is None:
                fence = marker
            continue
        match = re.match(r"^(#{1,6})\s+(.+?)\s*#*\s*$", line)
        if match and not fence:
            title = match[2]
            anchor = re.sub(r"[^\w\- ]", "", title.lower()).replace(" ", "-")
            count = counts.get(anchor, 0)
            counts[anchor] = count + 1
            result.append((len(match[1]), title, anchor + (f"-{count}" if count else "")))
    return result


def filename(key):
    return "index.html" if key == "README.md" else key.removeprefix("docs/").removesuffix(".md").replace("/", "-") + ".html"


def page_id(key):
    return "atlasium_" + filename(key)[:-5].replace("-", "_").lower()


def load_pages():
    english = ROOT / "docs/en-US"
    sources = sorted(english.rglob("*.md"))
    pages = {}
    for source in sources:
        relative = source.relative_to(english)
        key = "README.md" if relative.as_posix() == "home.md" else "docs/" + relative.as_posix()
        translated = ROOT / "docs/pt-BR" / relative
        if not translated.is_file():
            raise ValueError(f"Missing Portuguese translation: {translated}")
        pages[key] = {"en-US": source, "pt-BR": translated}
    return pages


def stage_markdown(key, language, pages, aliases):
    source = pages[key][language]
    text = source.read_text(encoding="utf-8")
    english_headings = headings(pages[key]["en-US"].read_text(encoding="utf-8"))
    local_headings = headings(text)
    if [h[0] for h in english_headings] != [h[0] for h in local_headings]:
        raise ValueError(f"Heading structure differs between languages: {key}")
    if not local_headings or local_headings[0][0] != 1:
        raise ValueError(f"Document needs a leading H1: {source}")
    anchor_aliases = dict(zip((h[2] for h in local_headings), (h[2] for h in english_headings)))

    def rewrite(href):
        url = urlsplit(href)
        if url.scheme or url.netloc:
            return href
        path = posixpath.normpath(posixpath.join(source.relative_to(ROOT).parent.as_posix(), unquote(url.path)))
        destination = aliases.get(path)
        if not url.path:
            return filename(key) + "#" + anchor_aliases.get(url.fragment, url.fragment)
        if destination:
            return filename(destination) + ("#" + url.fragment if url.fragment else "")
        if url.path.endswith(".md"):
            raise ValueError(f"Broken Markdown link in {source}: {href}")
        if path.startswith("docs/assets/"):
            return "../assets/" + path.removeprefix("docs/assets/")
        return "https://github.com/1mamute/atlasium/blob/main/" + path + ("#" + url.fragment if url.fragment else "")

    text = re.sub(r"(?<=\]\()([^\s)]+)", lambda m: rewrite(m[0]), text)
    text = re.sub(r'(?<=src=")([^"\s]+)', lambda m: rewrite(m[0]), text)
    output, fence, index = [], None, 0
    for line in text.splitlines():
        delimiter = re.match(r"\s*(`{3,}|~{3,})", line)
        if delimiter:
            marker = delimiter[1][0]
            fence = None if fence == marker else marker if fence is None else fence
        match = re.match(r"^(#{1,6})\s+(.+?)\s*#*\s*$", line)
        if match and fence is None:
            level, title, _ = local_headings[index]
            anchor = english_headings[index][2]
            if index:
                output.append(f"{'#' * (level - 1)} {title} {{#{page_id(key)}_{anchor}}}")
            index += 1
        else:
            output.append(line)
    title = local_headings[0][1]
    command = "\\mainpage Atlasium" if key == "README.md" else f"\\page {page_id(key)} {title}"
    return command + "\n\n" + "\n".join(output), title


class Document(HTMLParser):
    """Collect anchors, links and section headings for navigation and build validation."""

    def __init__(self, content):
        super().__init__()
        self.ids, self.links, self.sections = set(), [], []
        self.heading = None
        self.feed(content)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        for name in ("href", "src"):
            if attrs.get(name):
                self.links.append(attrs[name])
        if re.fullmatch(r"h[1-6]", tag):
            self.heading = {"level": int(tag[1]), "id": attrs.get("id"), "text": ""}
        if self.heading and attrs.get("id"):
            self.heading["id"] = attrs["id"]

    def handle_data(self, data):
        if self.heading:
            self.heading["text"] += data

    def handle_endtag(self, tag):
        if self.heading and re.fullmatch(r"h[1-6]", tag):
            if self.heading["id"]:
                self.sections.append(self.heading)
            self.heading = None


def rendered_content(raw, key):
    """Extract only Doxygen's balanced document body, without its navigation or crawler links."""
    start = re.search(r'<div class="textblock">', raw)
    if not start:
        raise ValueError(f"Doxygen HTML structure changed: {key}")
    depth = 1
    for token in re.finditer(r'</?div\b[^>]*>', raw[start.end():]):
        depth += -1 if token[0].startswith('</') else 1
        if depth == 0:
            content = raw[start.end():start.end() + token.start()]
            # The staging input shifts section levels to suit Doxygen's page context.
            content = re.sub(r'<(/?)h([1-5])\b', lambda m: f'<{m[1]}h{int(m[2]) + 1}', content)
            return content.replace(f'id="{page_id(key)}_', 'id="').replace(f'href="#{page_id(key)}_', 'href="#')
    raise ValueError(f"Unclosed Doxygen document body: {key}")


def validate_site(site):
    documents = {path: Document(path.read_text(encoding="utf-8")) for path in site.rglob("*.html")}
    errors = []
    for path, document in documents.items():
        for href in document.links:
            url = urlsplit(href)
            if url.scheme or url.netloc:
                continue
            target = (path.parent / unquote(url.path)).resolve() if url.path else path
            if not target.is_relative_to(site.resolve()) or not target.is_file():
                errors.append(f"{path.name}: missing local target {href}")
            elif url.fragment and target in documents and unquote(url.fragment) not in documents[target].ids:
                errors.append(f"{path.name}: missing section {href}")
    if errors:
        raise ValueError("Invalid documentation links:\n" + "\n".join(errors))
    print(f"Validated {len(documents)} HTML pages: all local links, images and section anchors exist.")


def build(doxygen):
    version = subprocess.run([doxygen, "--version"], check=True, capture_output=True, text=True).stdout.strip()
    numbers = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
    if not numbers or tuple(map(int, numbers.groups())) < (1, 18, 0):
        raise ValueError(f"Doxygen 1.18.0 or later is required; found {version}")
    print(f"Rendering with Doxygen {version}")
    pages = load_pages()
    aliases = {source.relative_to(ROOT).as_posix(): key for key, variants in pages.items() for source in variants.values()}
    site = (ROOT / ".build/site").resolve()
    build_root = (ROOT / ".build").resolve()
    if build_root != ROOT / ".build" or site != build_root / "site":
        raise ValueError("Build output must stay inside .build/site")
    build_root.mkdir(exist_ok=True)
    if site.exists():
        shutil.rmtree(site)
    site.mkdir()
    shutil.copytree(ROOT / "docs/assets", site / "assets", ignore=shutil.ignore_patterns("*.txt"))
    for asset in ("style.css", "app.js", "redirect.js"):
        shutil.copyfile(ROOT / "docs/site" / asset, site / "assets" / asset)
    template = (ROOT / "docs/site/template.html").read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="doxygen-", dir=build_root) as workdir:
        work = Path(workdir)
        for language in LANGUAGES:
            input_dir, output_dir = work / language / "input", work / language / "output"
            input_dir.mkdir(parents=True)
            titles = {}
            for key in pages:
                staged, titles[key] = stage_markdown(key, language, pages, aliases)
                (input_dir / filename(key).replace(".html", ".md")).write_text(staged, encoding="utf-8")
            config = (ROOT / "Doxyfile").read_text(encoding="utf-8")
            config += f'\nINPUT = "{input_dir.as_posix()}"\nOUTPUT_DIRECTORY = "{output_dir.as_posix()}"\n'
            config += "OUTPUT_LANGUAGE = " + ("English" if language == "en-US" else "Brazilian") + "\n"
            config_path = work / language / "Doxyfile"
            config_path.write_text(config, encoding="utf-8")
            subprocess.run([doxygen, str(config_path)], check=True, cwd=ROOT)
            destination = site / language
            destination.mkdir()
            for key in pages:
                generated = "index.html" if key == "README.md" else page_id(key) + ".html"
                raw = (output_dir / "html" / generated).read_text(encoding="utf-8")
                content = rendered_content(raw, key)
                sections = "".join(
                    f'<a href="#{escape(h["id"])}"' + (' class="subsection"' if h["level"] > 2 else '') + f'>{escape(h["text"].strip())}</a>'
                    for h in Document(content).sections
                )
                navigation = ""
                for group, keys in GROUPS:
                    navigation += f'<p class="nav-label">{LABELS[language][group]}</p>'
                    for target in keys:
                        if target not in pages:
                            raise ValueError(f"Navigation points at a missing document: {target}")
                        title = LABELS[language]["home"] if target == "README.md" else titles[target]
                        active = ' class="active" aria-current="page"' if target == key else ''
                        navigation += f'<a href="{filename(target)}"{active}>{escape(title)}</a>'
                values = dict(LABELS[language], language=language, title=escape(titles[key]), filename=filename(key),
                              browserTitle='Atlasium' if key == 'README.md' else escape(titles[key]) + ' · Atlasium',
                              englishSelected=' selected' if language == 'en-US' else '',
                              portugueseSelected=' selected' if language == 'pt-BR' else '',
                              navigation=navigation, sections=sections, content=content,
                              heading=f'<h1 class="{"sr-only" if key == "README.md" else "page-title"}">{escape(titles[key])}</h1>')
                rendered = template
                for name, value in values.items():
                    rendered = rendered.replace("{{" + name + "}}", value)
                (destination / filename(key)).write_text(rendered, encoding="utf-8")
    (site / "index.html").write_text(
        '<!doctype html><html lang="en-US"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<link rel="icon" type="image/png" href="assets/atlasium-favicon.png">'
        '<script src="assets/redirect.js" defer></script><title>Atlasium</title></head>'
        '<body><a href="en-US/index.html">English</a> · <a href="pt-BR/index.html">Português</a></body></html>',
        encoding="utf-8",
    )
    (site / ".nojekyll").touch()
    # Keep links to the previous English URLs working after the locale rename.
    legacy = site / "en"
    legacy.mkdir()
    for key in pages:
        target = "../en-US/" + filename(key)
        (legacy / filename(key)).write_text(
            '<!doctype html><html lang="en-US"><head><meta charset="utf-8">'
            '<link rel="icon" type="image/png" href="../assets/atlasium-favicon.png">'
            f'<script>location.replace("{target}" + location.hash);</script>'
            f'<title>Atlasium</title></head><body><a href="{target}">Continue</a></body></html>',
            encoding="utf-8",
        )
    validate_site(site)
    print(f"Documentation ready: {site}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--doxygen", default="doxygen", help="Doxygen executable (default: doxygen on PATH)")
    args = parser.parse_args()
    try:
        build(args.doxygen)
    except (ValueError, FileNotFoundError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Documentation build failed: {error}\n")
