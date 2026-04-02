# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an [Antora](https://antora.org/)-based documentation site for ownCloud Server. Documentation is written in AsciiDoc and built into a static HTML site. This repo is not built standalone in production — it is built as part of the main [owncloud/docs](https://github.com/owncloud/docs) repository, but can be built locally for preview.

## Commands

Install dependencies:
```
npm install
```

Build documentation (production, fetches remote content and UI bundle):
```
npm run antora
```

Build for local preview (outputs to `public/`, served at `http://localhost:8080`):
```
npm run antora-dev-local
```

Serve the built site:
```
npm run serve
```

Build with a custom local UI bundle (from `../docs-ui/`):
```
npm run antora-dev-bundle
```

Check for broken links (run after build):
```
npm run linkcheck
```

## Architecture

### Content Structure

Content lives under `modules/`, organized into Antora modules:
- `modules/ROOT/` — Main landing pages and shared navigation
- `modules/admin_manual/` — Administration documentation
- `modules/developer_manual/` — Developer documentation
- `modules/classic_ui/` — Classic UI documentation

Each module follows the Antora standard layout: `pages/` (AsciiDoc `.adoc` files), `partials/` (reusable fragments via `include::`), `images/`, `attachments/`, and `examples/`.

Navigation is defined in `modules/ROOT/partials/nav.adoc`.

### Key Config Files

- `antora.yml` — Defines this component (`server`, version `next`), PHP version attributes, and component-level AsciiDoc attributes
- `site.yml` — Production build config; pulls global attributes from `owncloud/docs` GitHub repo at build time
- `site-dev.yml` — Local/dev build config

### Custom Extensions

**AsciiDoc extensions** (`ext-asciidoc/`):
- `tabs.js` — Renders tabbed content blocks
- `remote-include-processor.js` — Allows including content from remote URLs

**Antora extensions** (`ext-antora/`):
- `generate-index.js` — Generates Elasticsearch search index
- `load-global-site-attributes.js` — Fetches and injects global attributes from `global-attributes.yml` in the main docs repo
- `find-orphaned-files.js` — Detects unreferenced files (disabled by default in `site.yml`)
- `comp-version.js` — Component version utilities

### Global Attributes

AsciiDoc attributes shared across all ownCloud documentation repos are maintained in the main `owncloud/docs` repository (`global-attributes.yml`). During a build, `load-global-site-attributes.js` fetches them from GitHub. A local copy at `./global-attributes.yml` can be used for offline development by editing `site.yml`.

### Build Output

Built site goes to `public/`. The UI bundle (CSS, JS, templates) is fetched from `https://minio.owncloud.com/documentation/ui-bundle.zip` unless overridden with `--ui-bundle-url`.

## Branching Workflow

- `master` maps to the `next` version on the published site
- Only three branches are maintained at a time: `master`, current release, and previous release
- All changes target `master` first, then are backported to version branches as needed
- Version branches are named after major.minor releases (e.g., `10.16`)
