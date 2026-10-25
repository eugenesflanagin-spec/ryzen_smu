# Credits

| who | what | where |
|---|---|---|
| Leonardo Gates (leogx9r) | Original author of the ryzen_smu driver, libsmu, monitor_cpu and the scripts | [gitlab.com/leogx9r/ryzen_smu](https://gitlab.com/leogx9r/ryzen_smu) |
| amkillam and contributors | Maintained fork this repository is forked from: merged fixes, new CPU support (Strix Point, Strix Halo, Granite Ridge, ...), kernel 7.2+ compatibility | [github.com/amkillam/ryzen_smu](https://github.com/amkillam/ryzen_smu) |
| Mario Oenning | Maintainer of the AUR package `ryzen_smu-dkms-git`, which the Arch package here was compared against | [aur.archlinux.org/packages/ryzen_smu-dkms-git](https://aur.archlinux.org/packages/ryzen_smu-dkms-git) |
| TuxTimings project | Open-source PM-table work used to cross-check starting offsets for the `0x540104` layout (the mapping here was measured independently) | TuxTimings |
| Eugene Flanagin | This fork: `0x540104` monitor_cpu, reference-clock scaling, monitor_cpu / test.py / dkms.conf fixes, packaging, docs | this repository |

Modified files keep their original copyright and licence headers; `userspace/monitor_cpu.c`
carries a note listing this fork's modifications.

Licences: the kernel driver (`drv.c`, `smu.c`, `smu.h`) is GPL-2.0 (`LICENSE`). The userspace
library and `monitor_cpu` are GPL-3.0-or-later (`lib/LICENSE`).

AMD, Ryzen and related names are trademarks of Advanced Micro Devices, Inc. This project is not
affiliated with or endorsed by AMD.
