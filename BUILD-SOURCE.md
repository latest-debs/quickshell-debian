# BUILD-SOURCE.md — how the quickshell source build works

Quickshell publishes no Linux binaries, so the stock
`debian-multiarch-builder` (binary-repack) cannot build it. This repo
compiles the Forgejo source tag once per suite in a
`debian:<suite>` container and wraps the result with `dpkg-deb`.

## Version detection

`.github/scripts/detect-version.sh` (fleet template + Forgejo fallback):

1. GitHub mirror `quickshell-mirror/quickshell` `releases/latest`
   (prerelease fallback included).
2. Forgejo tags API derived from `package.yaml:upstream_url`
   (`https://git.outfoxxed.me/api/v1/repos/quickshell/quickshell/tags`),
   highest semver tag wins.
3. Compare against this repo's newest tag; build only when newer.

Manual dispatch with an explicit tag always builds (dedupe guard bypass).

## Build matrix (`.github/workflows/release.yml`)

- Suites: trixie, forky, sid (bookworm Qt 6.4 < required 6.6 private
  headers; bullseye has no Qt6). trixie's `wayland-protocols` (1.44) predates
  `staging/ext-background-effect-v1`, so its container overlays forky's
  version (arch-all protocol XML, build-time only); forky/sid ship it already.
- Arches: amd64, arm64 (native runners; no QEMU in the pilot).
- Per cell: fetch `https://git.outfoxxed.me/quickshell/quickshell/archive/<tag>.tar.gz`,
  `cmake -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF`, `ninja`,
  `DESTDIR` stage, `dpkg-deb -b`, `lintian`.
- Artifacts named `<pkg>_<ver>-<build>.<suite>_<arch>.deb` so
  `apt-repo/build-repo.sh` folds them into `pool/` + `dists/` unchanged.

## Smoke gate

`trixie` container: `dpkg -i` the built `.deb`, `qs --version` must print
the expected tag. Wayland-session behavior is out of scope for CI.

## Provenance

Same as the binary fleet: `provenance.json` (builder ref, run URL,
source commit, SHA-256 of every artifact, upstream tag + tarball digest),
`sbom.spdx.json`, Sigstore attestations, draft-before-publish.
The vet-time pin is the source-tarball SHA-256, not a binary asset digest.
