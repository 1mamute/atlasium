# Documentation publishing

The documentation site uses Doxygen to render the repository Markdown. The theme uses the approved
wiki layout. English and Brazilian Portuguese have separate pages. The language control keeps the
current page and section. The theme control selects light or dark mode and remembers the choice.

## Sources

- `docs/en-US/home.md` is the English home page. Its title stays in the source. The site shows the logo
  instead of a second visible title.
- `docs/pt-BR/home.md` is the Portuguese home page.
- Each other Markdown document in `docs/en-US/` becomes one page. Contributor documents stay in
  `docs/en-US/contributing/`.
- Portuguese documents mirror those paths in `docs/pt-BR/`. Every English page needs a translation.
  Keep the same heading levels and order in both languages.
- `docs/site/` contains the HTML template, stylesheet and browser script.
- `Doxyfile` contains the renderer settings. `tools/build_docs.py` prepares the input, runs Doxygen
  and applies the theme. It checks local links, images and section anchors.

Edit the Markdown sources. Do not edit `.build/site/`; the next build replaces it.
Keep the root `README.md` overview in sync with both home pages.
The published language folders are `en-US/` and `pt-BR/`. Shared theme files stay in `docs/site/`.
Keep commands, API names and code examples unchanged in translations.
The build gives both languages the English section IDs, so links and language changes keep working.

## Local build

1. Install Python 3.10 or later and Doxygen 1.18.0 or later. Add both executables to `PATH`.
2. From the repository root, run:

   ```
   python tools/build_docs.py
   ```

   For a portable Doxygen executable, use `--doxygen "<path to doxygen.exe>"`.

3. Serve the generated site:

   ```
   python -m http.server 8000 --directory .build/site
   ```

4. Open `http://localhost:8000/`. Check both languages, themes and the changed page.

The build needs no Python packages. `.gitignore` excludes generated pages and local build tools.

## GitHub Pages setup

1. Open the repository's **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Push the documentation and `.github/workflows/docs.yml` to `main`.
4. Open **Actions → Documentation**. Wait for the build and deployment to finish.

The site URL is `https://1mamute.github.io/atlasium/`.
The workflow builds both languages, checks links and uploads the site artifact.
It uses the official Doxygen 1.18.0 Linux release and verifies its SHA-256 checksum.
The deployment job publishes that artifact with the `github-pages` environment.
If the environment requires approval, approve the deployment in Actions.

## Publish updates

1. Update the English document and its Portuguese translation.
2. Run the local build and review the result.
3. Commit and push the changes to `main`.
4. Check the **Documentation** workflow for the published URL.

Pull requests build and validate the site without publishing it.
You can also run the workflow from **Actions → Documentation → Run workflow**.
