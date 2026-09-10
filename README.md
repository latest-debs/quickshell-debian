# quickshell for Debian

[quickshell](https://git.outfoxxed.me/quickshell/quickshell) — flexible
QtQuick based desktop shell toolkit — packaged for Debian as part of
[latest-debs](https://github.com/latest-debs).

> **Pilot: first source-built package in this org.** Every other
> `*-debian` repo repacks an upstream binary; quickshell publishes no
> binaries, so this repo compiles from the Forgejo source tag per suite
> (see `BUILD-SOURCE.md`). Bookworm/bullseye are skipped (Qt6 too old /
> absent); trixie, forky, sid ship, Ubuntu LTS via the apt-repo alias.

## Install

```sh
sudo apt install extrepo  # if not already installed
sudo extrepo enable latest-debs
sudo apt update
sudo apt install quickshell
```

Or download a `.deb` from the Releases page:

```sh
sudo apt install ./quickshell_*.deb
```

## Verify

```sh
apt-cache policy quickshell
qs --version
```

## Supported distributions & architectures

- Debian Trixie (13), Forky (14/testing), Sid (unstable)
- amd64, arm64 (pilot scope; exotic arches unproven for Qt+Wayland)
- Ubuntu Noble/Resolute/Questing via the apt-repo Debian-alias fallback

## Building

Run the **Build quickshell for Debian** workflow with the desired upstream
tag (e.g. `v0.3.1`). Packaging is driven by `package.yaml`
(`build_mode: source`) + `.github/workflows/release.yml` (per-suite sbuild).

## Parity exception

Debian is currently behind us — it carries only `0.3.0-1` (forky/sid;
trixie via backports) while we build the current `0.3.1` — so no released
suite is at parity. A parity exception is nevertheless recorded
(`../apt-repo/parity-exceptions.json`, review 2026-12-01, expiry
2027-03-01) as a guard: if trixie proper ever reaches >= our upstream, the
pilot keeps serving Ubuntu LTS/backports users until reviewed.

## Disclaimer

Unofficial, volunteer-run packaging — **best-effort, no SLA**.

## License

Packaging scripts in this repo are MIT-licensed. Quickshell itself remains
under its upstream license (`LGPL-3.0-only`).
