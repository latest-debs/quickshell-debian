# BUILD-SOURCE.md — how the quickshell source build works

quickshell publishes no Linux binaries, so it is packaged with
[debian-multiarch-builder](https://github.com/ranjithrajv/debian-multiarch-builder)'s
`build_mode: source` (see that repo's `examples/source-mode-package.yaml`).
The standard scaffold workflow drives it — there is no repo-local build script.

## Configuration (`package.yaml`)

- `build_mode: source`, `build_system: cmake`
- `upstream_url`/`upstream_ref` — the Forgejo tag, fetched as
  `<url>/archive/<ref>.tar.gz` (GitHub is only a tag-detection mirror)
- `build_suites` trixie/forky/sid; `skip_suites` bullseye/bookworm (Qt6 too
  old / absent)
- `architectures` amd64/arm64 — native runners, no QEMU/cross
- `build_depends` derived from upstream BUILD.md + each
  `find_package`/`pkg_check_modules` in the tree
- `cmake_flags` `-DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF`
- `build_apt_sources` / `build_depends_suites` — trixie installs forky's
  `wayland-protocols` (1.44 predates `staging/ext-background-effect-v1`,
  required by the background_effect module)

## How it builds

`.github/workflows/release.yml` (scaffold template) computes a per-architecture
native matrix, then the builder bakes a per-suite image (toolchain +
`build_depends`), exports a chroot tarball under `/tmp/download_cache/chroots/`,
and compiles the tag once in that chroot (`unshare`/`chroot`, not `docker run`)
with `ccache`. Forky and sid re-wrap in parallel in their own chroots. Each wrap
recomputes runtime `Depends`
with that suite's `dpkg-shlibdeps` and `dpkg-deb`. Artifacts use the fleet naming
`quickshell_<ver>-<build>+<suite>_<arch>.deb`, so `apt-repo/build-repo.sh`
folds them into `pool/` + `dists/`.

## Smoke gate

On trixie the built `.deb` is installed and `qs --version` must print the
expected tag. Wayland-session behaviour is out of scope for CI.

## Provenance

Same as the binary fleet: `provenance.json`, `sbom.spdx.json`, Sigstore
attestations, draft-before-publish. The vet-time pin is the source-tarball
SHA-256, not a binary asset digest.
