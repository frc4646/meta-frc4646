# meta-frc2910 AGENTS.md

## Project context

Yocto 6.0 (wrynose) image for NVIDIA Jetson Orin (AOS target). BSP: meta-tegra, JetPack 7.2.1 / L4T rel-39.2. Image: `demo-image-base`.

## Layout

- Layer submodules under `layers/` (point into `repos/`): `openembedded-core`, `bitbake` (master), `meta-yocto`, `meta-tegra`, `meta-tegra-community`, `meta-openembedded`, `meta-virtualization`, `meta-clang` — all on `wrynose` unless noted.
- Project customizations: `layers/meta-tegrademo/` (appends, templates, packagegroups, patches).
- Build dir: `build/` — gitignored, generated. Config source of truth: `layers/meta-tegrademo/conf/templates/tegrademo/{local.conf,bblayers}.sample`; `setup-env` regenerates `build/conf/` from these.
- Setup scripts in `scripts-setup/` (`setup-env-internal` parser); `setup-env` wrapper at repo root.
- Post-build: `to_xfs.py` converts the tegraflash ext4 rootfs to XFS (see *Why XFS rootfs* below). Don't skip for production.

## Build & flash

See `README.md` for exact commands. Steps:

1. `. setup-env --machine <MACHINE> build` (must use `.` not `./`).
2. `bitbake demo-image-base`.
3. `../to_xfs.py <in>.tegraflash-tar.gz <out>.tegraflash-tar.zst` — skip only for throwaway iterations.
4. Flash: extract the tarball on a USB-connected host with the Jetson in recovery mode, `sudo ./initrd-flash` (`initrd-flash` ships in the tarball, not the repo).

Suffixes: bitbake emits `.tegraflash-tar.zst` (hyphen); `to_xfs.py` takes `.tegraflash-tar.gz` (the `.gz` is the documented convention — GNU tar auto-detects the actual zstd compression) and emits `.tegraflash-tar.zst`.

## MACHINE configurations

See `README.md`'s "Supported hardware" table.

## Conventions

- Branches: `frc<team>-<codename>`.
- Commits: see *Writing* below; optional `Signed-off-by:`.
- Push: standard fork workflow (PR upstream).

## Gotchas

- **`linux-noble-nvidia-tegra` fetch failure**: per-recipe shallow clone already in `local.conf.sample`:
  ```
  BB_GIT_SHALLOW:pn-linux-noble-nvidia-tegra = "1"
  BB_GIT_SHALLOW_DEPTH:pn-linux-noble-nvidia-tegra = "1"
  ```
  Also scoped to `pn-systemd`, `pn-python3-pefile`. Do NOT enable globally — breaks `devtool upgrade`, src-package, archiver. Details: `/memories/repo/yocto-fetch-failures.md`.
- **`build/conf/` is regenerated**: edits are lost on next `setup-env`. Persistent changes go in `local.conf.sample`.
- **`build/` is gitignored**: if `git status` shows anything under `build/`, `.gitignore` is broken.

## Why XFS rootfs

`to_xfs.py` runs `mkfs.xfs -d su=128k -d sw=1 -L rootfs` — aligns the allocator to NVMe 128 KiB erase blocks. Don't skip without reason.


## Writing: comments and commits
Short and only the *why*. If `git show` (or the code) already says it, drop it.
- Hard limits: every line **≤80 chars** (including leading whitespace);
  inline comment **≤2 lines** (none best), docstring **≤5 lines**;
  commit subject **≤70 chars**, commit body **≤10 lines** (often zero,
  ≤80 chars per line — one short sentence, not a paragraph wrapped to fit).
- Subject is `<imperative>` describing the change (`add X`), not the file
  (`edit responses.py`). For Yocto, `<recipe>: <imperative>` per OE style.
- Body is **default-zero**: omit anything `git show` already says, anything
  a fluent reader of the stack knows, and any hunk paraphrase. Keep only a
  *why* the diff can't carry — a non-obvious constraint, workaround
  rationale, superseded-commit drop, or review-fix anchor. If the subject
  plus the diff are self-explanatory, the body is empty.
- Comments: only a non-obvious constraint, past failure, or forward-compat
  hazard. Never narrate the next line, never restate the signature/params/spec
  list — those live in the code or docstrings elsewhere. Same for `:param:`/
  `:returns:` blocks in commits.


## Yocto recipes and layers
This repo is a Yocto distro; the rules above apply plus these.
- Custom layers live under `layers/` (`meta-tegrademo`, `meta-tegra-support`,
  `meta-demo-ci`). Submodules under `repos/` are upstream — don't commit to
  them; fix upstream and bump the submodule ref here instead.
- Prefer a `.bbappend` with the `%.bbappend` wildcard version over copying or
  forking an upstream `.bb` recipe; start every append with
  `FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"`.
- Don't bump `PR` for recipe edits — the autobuilder's PR-service handles
  that. Only set `PR` when inheriting from a non-PR-service recipe.
- For git recipes use `SRCREV = "${AUTOREV}"` (or pin a SHA when
  reproducibility matters); never hardcode a branch HEAD literal.
