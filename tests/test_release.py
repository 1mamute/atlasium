"""Check distribution boundaries and version safeguards without WoW or Lua."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load_tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release = load_tool("package_release")
commit = load_tool("check_commit")


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        files = {
            "Atlasium/Atlasium.toc": "## Version: 1.0.0\nCore.lua\nData\\Tiles.lua\n",
            "Atlasium/Core.lua": "-- runtime\n",
            "Atlasium/Data/Tiles.lua": "-- data\n",
            "Atlasium/unneeded.txt": "exclude",
            "README.md": "# Atlasium\n",
            "CHANGELOG.md": "# Changelog\n\n## [1.0.0] - 2026-10-04\n\nFirst release.\n\n## [0.1.0]\nOld.\n",
            "LICENSE": "license",
            "docs/en-US/usage.md": "# Usage\n",
            "docs/pt-BR/usage.md": "# Uso\n",
            "docs/en-US/contributing/testing.md": "exclude",
            "docs/pt-BR/contributing/testing.md": "exclude",
            "docs/site/index.html": "exclude",
            "docs/site/unneeded.md": "exclude",
            "docs/assets/logo.png": "exclude",
            "tests/core_spec.lua": "exclude",
            ".env": "exclude",
        }
        for name, content in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def test_archive_contains_only_runtime_and_player_docs(self):
        output = self.root / "output"
        archive = release.build_release(self.root, "v1.0.0", output)
        with zipfile.ZipFile(archive) as bundle:
            self.assertEqual(set(bundle.namelist()), {
                "Atlasium/Atlasium.toc", "Atlasium/Core.lua", "Atlasium/Data/Tiles.lua",
                "README.md", "CHANGELOG.md", "LICENSE", "docs/en-US/usage.md", "docs/pt-BR/usage.md",
            })
        first = archive.read_bytes()
        self.assertEqual(first, release.build_release(self.root, "v1.0.0", output).read_bytes())
        self.assertEqual((output / "notes.md").read_text(encoding="utf-8"), "First release.\n")
        import hashlib
        self.assertEqual(archive.with_suffix(".zip.sha256").read_text(encoding="utf-8"),
                         f"{hashlib.sha256(first).hexdigest()}  {archive.name}\n")

    def test_invalid_or_mismatched_tags_fail(self):
        for tag in ("v1", "1.0.0", "v01.0.0", "v1.0.0-01", "v1.0.1"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.release_files(self.root, tag)

    def test_excluded_documentation_links_point_to_tagged_sources(self):
        readme = self.root / "README.md"
        readme.write_text('[Usage](docs/en-US/usage.md)\n'
                          '[Tests](docs/en-US/contributing/testing.md)\n'
                          '<img src="docs/assets/logo.png">\n', encoding="utf-8")
        text = release.distribution_markdown(readme, release.release_files(self.root, "v1.0.0"),
                                             self.root, "v1.0.0")
        self.assertIn('[Usage](docs/en-US/usage.md)', text)
        self.assertIn('https://github.com/1mamute/atlasium/blob/v1.0.0/docs/en-US/contributing/testing.md', text)
        self.assertIn('https://github.com/1mamute/atlasium/blob/v1.0.0/docs/assets/logo.png', text)

    def test_semver_prereleases_and_metadata(self):
        for version in ("1.1.0-rc.1", "1.0.0+build.01", "1.0.0-alpha.1+build.2"):
            self.assertIsNotNone(release.SEMVER.fullmatch(version))

    def test_missing_runtime_file_fails(self):
        (self.root / "Atlasium/Core.lua").unlink()
        with self.assertRaises(ValueError):
            release.release_files(self.root, "v1.0.0")

    def test_toc_cannot_include_project_files(self):
        with (self.root / "Atlasium/Atlasium.toc").open("a", encoding="utf-8") as toc:
            toc.write("../.env\n")
        with self.assertRaises(ValueError):
            release.release_files(self.root, "v1.0.0")

    def test_missing_changelog_section_fails(self):
        with self.assertRaises(ValueError):
            release.release_notes(self.root, "v2.0.0")

    def test_simple_commit_subjects(self):
        for subject in ("feat: add notes", "fix: restore terrain", "docs: update guidance"):
            self.assertTrue(commit.is_valid_subject(subject))
        for subject in ("Update map", "feat: ", "feat: add notes\nextra", "unknown: add notes",
                        "feat(map): add notes", "feat!: migrate data", "feat: add notes\rextra"):
            self.assertFalse(commit.is_valid_subject(subject))


if __name__ == "__main__":
    unittest.main()
