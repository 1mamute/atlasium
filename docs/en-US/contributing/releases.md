# Versioning and releases

Atlasium follows [Semantic Versioning 2.0.0](https://semver.org/).
Commit subjects and pull request titles use the simple format `type: description`.

## Version numbers

`Atlasium/Atlasium.toc` is the version source. Use `MAJOR.MINOR.PATCH`, without a `v` prefix.
Git tags use the same version with a `v` prefix, for example `v1.0.0`.

The compatibility contract covers documented slash commands, settings, saved data and supported game clients.
Internal Lua functions in `ns` are not a public API.

- Increase PATCH for compatible bug fixes, for example `1.0.0` to `1.0.1`.
- Increase MINOR for compatible features, for example `1.0.1` to `1.1.0`.
- Increase MAJOR for incompatible changes, for example `1.1.0` to `2.0.0`.
- Use a prerelease suffix for test releases, for example `1.1.0-rc.1`.

Document breaking changes and migration steps in `CHANGELOG.md`. Never move a published tag or replace its archive.
Planned features do not prevent a stable release of the available features.
Experimental features keep their experimental status in stable releases.

## Commit messages

Use this format for new commits and pull request titles:

```text
type: description
```

Use `feat` for new features and `fix` for bug fixes.
Other types are `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` and `revert`.
Do not add a scope, such as `feat(map):`, or `!` to the subject.
Use a `BREAKING CHANGE:` footer for incompatible changes.

```text
feat: add map notes
fix: restore terrain after loading
feat: replace a saved setting

BREAKING CHANGE: explain the setting migration here
```

`feat` normally requires a MINOR release. `fix` normally requires a PATCH release.
A breaking change requires a MAJOR release, regardless of its type.
Other types do not require a player release by themselves.
The maintainer selects the next version from all changes since the previous tag.

CI checks pull request titles. Squash merges use the pull request title as the commit subject.
Existing history stays unchanged. Before a direct commit, check its subject:

```text
python tools/check_commit.py "chore: prepare the next release"
```

## Publish a release

1. Merge the release changes into `main` with a `type: description` title.
2. Update the TOC version and add a matching section in `CHANGELOG.md` before the merge.
3. Run `luacheck Atlasium tests`, `busted` and `python -m unittest discover -s tests -p 'test_*.py'`.
4. Run `python tools/package_release.py --tag v1.0.0` with the selected version.
5. Inspect `.build/release/Atlasium-v1.0.0.zip`.
6. Create and push the annotated tag from the release commit:

   ```text
   git tag -a v1.0.0 -m "Atlasium v1.0.0"
   git push origin v1.0.0
   ```

The Release workflow runs the checks again. It verifies that the tag matches the TOC version.
It publishes the ZIP, a SHA-256 checksum and the matching changelog section on GitHub.
Tags with a prerelease suffix produce GitHub prereleases.
If a workflow fails, fix the cause and rerun it before a release exists.
After publication, use a new version for changes.

## Archive contents

The ZIP contains the TOC, every file listed in it, `README.md`, `CHANGELOG.md`, `LICENSE`,
and Markdown files under `docs/`, except any `contributing` directory.
The debug modules stay in the archive because the TOC loads them; they activate only in debug mode.

Tests, developer tools, workflows, contributor docs, website files, images and local configuration stay out.
The packager redirects links to excluded contributor pages and images to the tagged files on GitHub.
GitHub also provides automatic source archives. Players must use the attached `Atlasium-v*.zip` distribution.
