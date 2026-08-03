# AxlRoseWIP

<!-- INTRO:START -->
<p align="center">
  <img src="preview/preview_v2026.0705.png" alt="AxlRose's WIP (Incomplete)">
</p>

Work in Progress mod (manually set at the top of list)

- Few field upscaled backgrounds and field character textures
- Enhanced UI and Themes plus tons of new stuff

## Latest release: v2026.0705

```
v2026.0705 > FIELD BACKGROUNDS!:
      - 4x Upscales: 157/877 (Balamb Garden COMPLETE)
      - Custom: 20/877

  UI:
      - Replaced Remaster fonts with perfect monospaced fonts - New Avatar pack options
      (JamesTheCat and AxlRose) - New Start Screen options (AxlRose or Vanilla) - New cursor
      options (Gunblade or Hand) - New option for controller buttons (Keyboard, PlayStation
      or XBox) - Enhanced UI and Themes: Blue Gradient, FF9 Blue, FF9 Black, Vanilla, Purpur
      and Light Purple are NEW

  Field character models:
      - Squall's d000 and d001 field model (low/high poly model)
```
<!-- INTRO:END -->

## Installing

This mod ships as an `.iroj` file inside `AxlRoseWIP.7z`, so it is not a drop-in
texture pack. It needs [Junction VIII](https://github.com/tsunamods-codes/Junction-VIII),
the Final Fantasy VIII mod manager, which unpacks the `.iroj` and drives all of its
in-game options.

Install it from the Junction VIII catalog, or download `AxlRoseWIP.7z` from
[Releases](https://github.com/AxlRose-RX/AxlRoseWIP/releases) and import it by hand.
Every version ever built is kept there.

Once installed, drag the mod to the **top of your mod list**.

Questions, screenshots and bug reports: [Tsunamods Discord](https://discord.com/invite/7Rsvsewghz)

<details>
<summary><b>Repository and build pipeline</b> (click to expand)</summary>

## Layout

```
src/                        mod source, mod.xml at its root
  mod.xml
  Preview/preview.png       in-manager preview, packed into the .iroj
  ...
preview/                    versioned copies served to the catalog, NOT packed
  preview_v2026.0705.png
catalog-meta.xml            catalog-only fields (Tags, CompatibleGameVersions)
.github/workflows/
  build.yml                 manual build workflow
  prepare.ps1               reads the version out of src/mod.xml
  package.ps1               .iroj -> .7z -> catalog-mod.xml, README, release body
  commit-preview.ps1        commits the versioned preview and the README
  prune.ps1                 removes older releases (off by default)
```

## Releasing a new version

1. Add, replace or delete files under `src/`.
2. Edit `src/mod.xml`: bump `<Version>` to the new date (`YYYY.MMDD`, e.g. `2026.0802`)
   and update `<Description>` / `<ReleaseNotes>`. Leave `<ReleaseDate>` alone, it is the
   date the mod was first started.
3. Replace `src/Preview/preview.png` with this version's art.
4. Update `catalog-meta.xml` if the tag list changed.
5. Commit and push. **Nothing builds automatically.**
6. Actions tab -> AxlRoseWIP -> Run workflow.

The build produces a release tagged `v<Version>` with two assets:

| Asset | Purpose |
| ----- | ------- |
| `AxlRoseWIP.7z` | the mod, what Junction VIII downloads |
| `catalog-mod.xml` | ready to paste into the Junction VIII catalog |

Older releases are kept. The `prune_old_releases` input deletes them, and is off
by default.

## Generated content

The block between the `INTRO:START` and `INTRO:END` comment markers at the top of this README is
rewritten by every build from `src/mod.xml`: the banner points at this version's
preview, the blurb is `<Description>` and the code block is `<ReleaseNotes>`. Editing
it by hand is pointless, the next build overwrites it. Everything outside those two
markers is hand written and never touched.

The release page body is built the same way, with the version's preview art on top.

The preview image is deliberately **not** a release asset. GitHub serves release
assets as `application/octet-stream` with an attachment disposition, so sites that
render the catalog (ff7catalog.com and friends) cannot embed them. Instead the build
copies `src/Preview/preview.png` to `preview/preview_v<Version>.png`, commits it to the
branch, and serves it from `raw.githubusercontent.com`.

`preview/` sits outside `src/` on purpose, so the accumulating older previews are
never packed into the `.iroj`.

The intermediate `.iroj` is built on the runner and discarded. It is usually over
GitHub's 2 GiB per-file release limit and is not needed by anyone.

## Workflow inputs

| Input | Default | Effect |
| ----- | ------- | ------ |
| `publish` | on | Publish a release. Turn off for a build-only dry run. |
| `prune_old_releases` | off | Delete every release except the one just built. |

## Catalog

`catalog-mod.xml` from the latest release goes to
[Junction-VIII-Catalogs](https://github.com/tsunamods-codes/Junction-VIII-Catalogs)
at `mods/AxlRose_WIP/mod.xml`.

Both URLs it contains point at `releases/latest/download/`, so they keep working
across versions and never need editing:

```
iroj://Url/https$github.com/AxlRose-RX/AxlRoseWIP/releases/latest/download/AxlRoseWIP.7z
```

The preview URL is versioned, so a new release never collides with a cached copy of
the old image, and the branch is read from the build rather than hardcoded, so a
branch rename fixes itself on the next build:

```
https://raw.githubusercontent.com/AxlRose-RX/AxlRoseWIP/canary/preview/preview_v2026.0705.png
```

## Working with the repo locally

Before the first `git add`, and once per clone:

```
git config core.autocrlf false
git config core.longpaths true
```

`src/` is large. Use GitHub Desktop or the CLI, not the web uploader, which caps at
25 MB and 100 files. If a first push exceeds 2 GiB, split it into several commits and
push between each.

Deleting a file in a later commit does not shrink the repo, the old blob stays in
history. When history gets too heavy, back up the workflow files and recreate the
repo clean.

</details>
