# Changelog (eugenesflanagin-spec/ryzen_smu fork)

Changes of this fork relative to [amkillam/ryzen_smu](https://github.com/amkillam/ryzen_smu).
The kernel module itself is unchanged from amkillam `main` (module version 0.1.7). Package
versions are `<upstream module version>.raphael<N>`.

## [0.1.7.raphael2] - 2026-10-25

First published release of this fork.

### Added
- `monitor_cpu`: live view for PM table `0x540104` (Ryzen 7000 "Raphael", e.g. 7800X3D),
  showing only fields validated against independent sensors.
- `monitor_cpu`: reference-clock (BCLK / eCLK) scaling, auto-detected from the TSC; `-b<MHz>`
  overrides it.
- Arch Linux package `ryzen_smu-raphael-dkms` (`packaging/arch/PKGBUILD`,
  `packaging/build-local-pkg.sh`).
- GitHub Actions release workflow: builds the module against the Arch `linux-headers`, builds
  the package, install-tests it in a fresh container, releases on `v*` tags.
- `docs/USER-GUIDE.md`, `CREDITS.md`, this changelog, a fork section in `README.md`.

### Fixed
- `monitor_cpu -h` no longer needs an argument; `-u<seconds>` is implemented (1-3600 s);
  `-f` refuses tables smaller than the 0x240903 layout instead of reading past the buffer, and
  no longer crashes on a missing "Overdrive Scalar" string.
- `scripts/test.py`: code-name list follows the driver's enum (22 = Strix Point,
  24 = Hawk Point, up to 26 = Strix Halo).
- `dkms.conf` is usable as is (no `@VERSION@` / `@CFLGS@` placeholders).
- README: sysfs permissions as the driver really sets them; code name 26 = Strix Halo.

### Versions
- DKMS / package version `0.1.7.raphael2`; `drv_version` stays `0.1.7`, because `libsmu`
  tools require that exact string.
- (`0.1.7.raphael1` was an unpublished test build with only the `0x540104` monitor.)
