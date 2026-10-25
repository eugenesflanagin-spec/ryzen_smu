# ryzen_smu — User Guide

A Linux kernel driver that lets programs talk to the management chip inside AMD Ryzen
processors.

This guide is for anyone installing this fork, from first-time Linux users to people who write
their own monitoring tools. It starts in plain words, then gives the detail, then every option.
A glossary is at the end.

---

## 1. In plain words

Every modern AMD Ryzen CPU has a small helper processor built in, called the **SMU** (System
Management Unit). The SMU watches temperatures, power and clock speeds, and it enforces the
power limits. Normally only the firmware (BIOS) and Windows tools like Ryzen Master talk to it.

**ryzen_smu** is a kernel module (a driver) that opens a small door to the SMU on Linux. Once it
is loaded, a folder appears at `/sys/kernel/ryzen_smu_drv/`. Programs read and write little files
in that folder to:

- read the SMU firmware version and the CPU's code name;
- read the **PM table**, a live block of numbers with temperatures, voltages, clocks and power
  (on supported CPUs);
- send commands to the SMU (advanced, and risky: see the warning below).

On its own the driver shows you nothing. You use it through a tool: the included
`monitor_cpu`, the Python scripts in `scripts/`, or third-party programs such as
`ryzen_monitor`, `ryzenadj`-style tools, ZenStates-style tuners and system-information apps.

> **Warning.** Reading is safe. **Writing** to the command files can change power limits,
> voltages and clocks while the computer is running. A wrong value can crash the machine or,
> in the worst case, damage hardware. The original author's warning applies: use at your own
> risk. Nothing in this guide asks you to write a command unless a section says so in bold.

### Who it is for

- People who want CPU sensor data that `k10temp` and `sensors` don't give (per-core voltage,
  FCLK/UCLK/MCLK, SoC voltage, package power).
- People running tools that need it (many Ryzen monitoring and tuning apps on Linux list
  `ryzen_smu` as a requirement).
- Developers writing their own SMU or PM-table tools.

### What this fork is

The original driver was written by **Leonardo Gates** (leogx9r) on GitLab and is no longer
maintained. **amkillam/ryzen_smu** on GitHub took it over, merged the pending fixes and keeps
adding CPUs (Strix Point, Strix Halo, kernel 7.2+ fixes).

This repository, `eugenesflanagin-spec/ryzen_smu`, is a GitHub fork of amkillam's repository:

| branch | contents |
|---|---|
| `main` | **identical** to amkillam/ryzen_smu `main` (0 commits ahead, 0 behind, checked 2026-10-25) |
| `raphael-0x540104-pm-table` | `main` + one commit: `monitor_cpu` support for PM table version `0x540104` (Ryzen 7000 "Raphael", e.g. 7800X3D) and a reference-clock (`-b`) option. Offered upstream as amkillam/ryzen_smu pull request #54 (open at the time of writing). |
| `raphael-release` (default branch) | That branch + small fixes (`monitor_cpu -h`/`-u`/`-f`, `scripts/test.py` code names, a `dkms.conf` that works as is, README corrections) + the Arch package, this guide and the release workflow. Releases are tagged from here, e.g. `v0.1.7.raphael2`. |

So the **driver** (the kernel module) is the same whichever you install. The differences are
in `monitor_cpu`, the scripts, `dkms.conf` and the documentation.

---

## 2. Requirements

| need | detail |
|---|---|
| CPU | AMD Ryzen / Threadripper / EPYC of a supported family (list below). Intel CPUs and AMD CPUs older than Zen are not supported. |
| Kernel | Linux 4.19 or newer (the source refuses to build on older kernels). Tested by upstream on current kernels including 7.2 and 7.3. |
| Kernel headers | The headers for **exactly** the kernel you run (`linux-headers` on Arch, `linux-headers-$(uname -r)` on Debian/Ubuntu, `kernel-devel` on Fedora). |
| Build tools | `gcc` (or the compiler your kernel was built with), `make`; `dkms` for the DKMS method; `git` to clone. |
| Root | Loading the module needs root. Writing to its files needs root. |
| Secure Boot | The module is unsigned. With Secure Boot on, the kernel refuses unsigned modules unless you sign it with your own key (MOK) or turn Secure Boot off. |

### Supported processors

Driver support (SMU access) — code names:
Colfax, Renoir, Picasso, Matisse, Castle Peak, Raven Ridge, Raven Ridge 2, Summit Ridge,
Pinnacle Ridge, Raphael, Rembrandt, Vermeer, Vangogh, Cezanne, Milan, Dali, Chagall, Naples,
Lucienne, Phoenix, Strix Point, Granite Ridge, Hawk Point, Storm Peak, Strix Halo.

PM table also available on: Granite Ridge (Ryzen 9000 desktop), Strix Point (Ryzen AI 300),
Strix Halo, Hawk Point (Ryzen 8000 mobile), Phoenix (Ryzen 8000 APU), Storm Peak
(Threadripper 7000), Raphael (Ryzen 7000 desktop), Chagall (Threadripper 5000), Vermeer
(Ryzen 5000 desktop), Castle Peak (Threadripper 3000), Matisse (Ryzen 3000 desktop), Cezanne,
Renoir, Picasso, Raven Ridge, Raven Ridge 2.

"PM table available" means the driver can fetch the raw table. Whether a **tool** can make
sense of it depends on whether that tool knows your table's layout (see section 8).

---

## 3. Install

Pick one method. DKMS is recommended because it rebuilds the module for you every time the
kernel is updated.

### 3a. Arch Linux: the release package from this fork (Ryzen 7000 users)

Download `ryzen_smu-raphael-dkms-<version>-x86_64.pkg.tar.zst` and `SHA256SUMS` from the
[Releases page](https://github.com/eugenesflanagin-spec/ryzen_smu/releases), then:

```sh
sha256sum -c SHA256SUMS --ignore-missing          # the package line must say OK
sudo pacman -S --needed dkms linux-headers         # headers for every kernel you boot
sudo pacman -U ryzen_smu-raphael-dkms-0.1.7.raphael2-1-x86_64.pkg.tar.zst
sudo modprobe ryzen_smu
```

It installs:

- the driver source in `/usr/src/ryzen_smu-0.1.7.raphael2/`; pacman's DKMS hook builds it for
  every installed kernel that has headers (clang-built kernels too: DKMS adds `LLVM=1` itself);
- `/usr/bin/monitor_cpu` with the `0x540104` (Raphael) view;
- the scripts in `/usr/share/ryzen_smu/scripts/` and the documentation in
  `/usr/share/doc/ryzen_smu-raphael-dkms/`.

It replaces `ryzen_smu-dkms-git` if that is installed (pacman asks; answer `y`). Programs that
need `ryzen_smu` (for example `ryzen_monitor`) keep working, because the package provides it.

To build it yourself instead: `git clone https://github.com/eugenesflanagin-spec/ryzen_smu`,
then `ryzen_smu/packaging/build-local-pkg.sh --install`.

### 3b. Arch Linux: AUR package (upstream, without the Raphael monitor)

```sh
yay -S ryzen_smu-dkms-git        # or paru, or any AUR helper
```

The AUR package `ryzen_smu-dkms-git` builds from **amkillam/ryzen_smu** — the same driver code
as this fork's `main`. It installs:

- the driver source in `/usr/src/ryzen_smu-<version>/`, registered with DKMS;
- `/usr/bin/monitor_cpu` (the stock one, without the `0x540104` support);
- `/usr/lib/depmod.d/ryzen_smu.conf` (lets the DKMS copy win over any other copy).

It does **not** install the Python scripts or the userspace library. Clone the repository if
you want those.

### 3c. Any distribution: DKMS from this fork

```sh
# Debian / Ubuntu example; use your distro's package names
sudo apt install dkms git build-essential linux-headers-$(uname -r)
# Arch: sudo pacman -S --needed dkms git base-devel linux-headers

git clone https://github.com/eugenesflanagin-spec/ryzen_smu.git
cd ryzen_smu
sudo make dkms-install
make -C userspace && sudo install -m755 userspace/monitor_cpu /usr/local/bin/
```

`make dkms-install` copies the source to `/usr/src/ryzen_smu-0.1.7.raphael2/`, writes the
version into `dkms.conf`, then runs `dkms add`, `dkms build` and `dkms install`. Proxmox users install
`proxmox-default-headers` instead of `linux-headers-$(uname -r)`.

Don't install more than one of: the release package, the AUR package, a manual
`make dkms-install` copy. They use different DKMS version names (`0.1.7.raphael2`,
`191.d298366`, ...), and you would end up with two copies fighting.

### 3d. Build and load by hand (no DKMS)

```sh
git clone https://github.com/eugenesflanagin-spec/ryzen_smu.git
cd ryzen_smu
make
sudo insmod ryzen_smu.ko
```

This lasts until reboot, and it has to be rebuilt after every kernel update.

### 3e. Only the `0x540104` monitor_cpu, keeping another driver install

The driver is unchanged, so you can keep a driver installed by 3b and build just the program:

```sh
git clone https://github.com/eugenesflanagin-spec/ryzen_smu.git
make -C ryzen_smu/userspace      # builds ryzen_smu/userspace/monitor_cpu
sudo ./ryzen_smu/userspace/monitor_cpu
```

### Load it now and at every boot

```sh
sudo modprobe ryzen_smu                      # load now (after DKMS / package install)
echo ryzen_smu | sudo tee /etc/modules-load.d/ryzen_smu.conf   # load at every boot
```

---

## 4. Check that it works

### Step 1: the kernel log

```sh
sudo dmesg | grep ryzen_smu
```

Example from a Ryzen 7 7800X3D on kernel 7.3:

```
ryzen_smu: loading out-of-tree module taints kernel.
ryzen_smu: module verification failed: signature and/or required key missing - tainting kernel
ryzen_smu: loading version: 0.1.7
ryzen_smu: CPUID: family 0x19, model 0x61, stepping 0x2, package 0x0
ryzen_smu: Family Codename: Raphael
ryzen_smu: SMU v4.84.4.0
```

The two "taints kernel" lines are normal for any module that isn't part of the kernel. They
are not errors.

### Step 2: the sysfs folder

```sh
ls -l /sys/kernel/ryzen_smu_drv/
cat /sys/kernel/ryzen_smu_drv/drv_version     # 0.1.7  (see the note below)
cat /sys/kernel/ryzen_smu_drv/version         # 4.84.4.0  (SMU firmware)
cat /sys/kernel/ryzen_smu_drv/mp1_if_version  # 2         (= interface v11)
cat /sys/kernel/ryzen_smu_drv/codename        # 20        (= Raphael)
```

The binary files need a hex viewer:

```sh
od -An -tx4 /sys/kernel/ryzen_smu_drv/pm_table_version   # 00540104
od -An -tu8 /sys/kernel/ryzen_smu_drv/pm_table_size      # 1704  (bytes)
```

`drv_version` says `0.1.7` even with the `0.1.7.raphael2` package. That is on purpose: the
kernel module is unchanged, and `libsmu`-based tools (`monitor_cpu`, `ryzen_monitor`, ...)
refuse to run unless it is exactly `0.1.7`. The `.raphael2` part is only the package and DKMS
version (`dkms status` shows `ryzen_smu/0.1.7.raphael2`).

If `pm_table`, `pm_table_size` and `pm_table_version` are missing, your CPU has no PM table
support (or the probe failed — check `dmesg`). If `rsmu_cmd` is missing, the RSMU mailbox is
not available on your CPU (always the case on Vangogh).

### Step 3 (optional): the self-test

```sh
sudo python3 /usr/share/ryzen_smu/scripts/test.py   # release package
sudo python3 scripts/test.py                        # from a git checkout
```

```
Retrieved SMU Version: v46.54.0
Processor Code Name: Matisse
PM Table: Supported
SMN Offset[0x50200]: 0x00001539

Everything seems to be working properly!
```

The test sends the harmless "get version" command (`0x02`) and reads one SMN address. That
involves **writing** to `smu_args`, `rsmu_cmd` and `smn`, but it changes no settings.
Its code-name list follows the driver (up to 26, Strix Halo). A code name newer than the list
is reported as unknown and the test carries on.

---

## 5. Everyday use

### Watch the CPU with monitor_cpu

```sh
sudo monitor_cpu          # live view, refreshes every second; Ctrl+C to quit
sudo monitor_cpu -m       # print memory timings once and exit
```

If you run it without `sudo`, it re-runs itself through `sudo` (`sudo -S`, so it may ask for
your password in the terminal). `-h` and `-v` work without root. `-u<seconds>` changes the
refresh interval (1–3600 s).

The stock `monitor_cpu` understands **only** PM table `0x240903` (Ryzen 3000 "Matisse").
On any other CPU it says the table is unsupported. `-f` forces it anyway, but it then reads your
table with the Matisse layout and prints a warning: the numbers are wrong. A table smaller than
the Matisse layout is refused instead of being read past its end.

With this fork (release package, `raphael-release` or `raphael-0x540104-pm-table`), a `0x540104` CPU gets its own view instead. It shows
only fields that were measured and confirmed on real hardware: per-core temperature and clock,
IOD hotspot, package power, FCLK, MCLK/UCLK, VSOC, VDDP, VID and per-core voltage.

### Read the PM table from a script

```sh
sudo python3 scripts/monitor_cpu.py      # Matisse (0x240903) layout; warns on other tables
sudo python3 scripts/dump_pm_table.py    # see the warning below
```

> **`dump_pm_table.py` runs a CPU load test.** It saves 15 PM-table dumps at idle, starts a
> stress program to load all cores, saves 15 more, then kills the stress program with
> `killall -9`. Only run it if you want that.

`scripts/read_dump.py` prints a saved table (`./dump.bin` in the current folder) as a list of
offsets and float values. That is the usual first step in working out a new table layout.

### Use it from your own C/C++ program

`lib/libsmu.c` + `lib/libsmu.h` wrap the sysfs files: `smu_init()`, `smu_free()`,
`smu_get_fw_version()`, `smu_codename_to_str()`, `smu_read_smn_addr()`, PM-table reads, and
command sending. The header must match the driver version you have installed. The README in
the repository has a complete example. Note the licence: `lib/` is GPL-3.0, while the driver
is GPL-2.0.

---

## 6. Reference: every file in /sys/kernel/ryzen_smu_drv/

**Permissions.** The upstream README says these files are root-only. The driver actually
creates them **readable by everyone** (`r--r--r--` and `rw-r--r--`), as you can see with
`ls -l`. Only root can write. A normal user can read the PM table and versions. Reading a
command file only returns the last result.

**Byte order.** Every binary value is little-endian.

| file | mode | type | what it holds |
|---|---|---|---|
| `drv_version` | read | text | Driver version, e.g. `0.1.7`. Tools check this. |
| `version` | read | text | SMU firmware version, e.g. `4.84.4.0` or `46.54.0`. It tracks your BIOS's AGESA. |
| `mp1_if_version` | read | text | MP1 mailbox interface: `0`=v9, `1`=v10, `2`=v11, `3`=v12, `4`=v13, `5`=undefined. |
| `codename` | read | text, 2 digits | CPU code name as a number (table below). |
| `smu_args` | read/write | 24 bytes | The six 32-bit arguments for the next command. Read it back after a command to get the six results. |
| `mp1_smu_cmd` | read/write | 32-bit | **Write**: send a command ID to the MP1 mailbox (using `smu_args`). **Read**: status of the last command. |
| `rsmu_cmd` | read/write | 32-bit | Same, for the RSMU mailbox. Only present if RSMU answers (never on Vangogh). |
| `hsmp_smu_cmd` | read/write | 32-bit | Same, for the HSMP mailbox (server/workstation parts). |
| `smn` | read/write | 32/64-bit | SMN register access. Write 4 bytes (an address), then read the 4-byte value. Write 8 bytes (address + value) to write a register. |
| `pm_table_size` | read | 64-bit | Size of `pm_table` in bytes. Only on PM-table CPUs. |
| `pm_table_version` | read | 32-bit | Layout version of the PM table, e.g. `0x540104`. Only on PM-table CPUs (and only if the SMU reports one). |
| `pm_table` | read | array of 32-bit floats | The live PM table. Each read asks the SMU for fresh data. |

### Code-name numbers (`codename`)

| # | name | # | name | # | name |
|---|---|---|---|---|---|
| 00 | Unknown | 09 | Summit Ridge | 18 | Naples |
| 01 | Colfax | 10 | Pinnacle Ridge | 19 | Chagall |
| 02 | Renoir | 11 | Rembrandt | 20 | Raphael |
| 03 | Picasso | 12 | Vermeer | 21 | Phoenix |
| 04 | Matisse | 13 | Vangogh | 22 | Strix Point |
| 05 | Threadripper | 14 | Cezanne | 23 | Granite Ridge |
| 06 | Castle Peak | 15 | Milan | 24 | Hawk Point |
| 07 | Raven Ridge | 16 | Dali | 25 | Storm Peak |
| 08 | Raven Ridge 2 | 17 | Lucienne | 26 | Strix Halo |

(26, Strix Halo, comes from the driver source. The upstream README table stops at 25.)

### Command status codes (read from a `*_cmd` file)

| value | meaning | value | meaning |
|---|---|---|---|
| `0x00` | waiting | `0xFB` | command timeout (driver) |
| `0x01` | OK | `0xFA` | invalid argument (driver) |
| `0xFF` | failed | `0xF9` | unsupported platform (driver) |
| `0xFE` | unknown command | `0xF8` | insufficient buffer size (driver) |
| `0xFD` | rejected: prerequisite unmet | `0xF7` | memory map error (driver) |
| `0xFC` | rejected: busy | `0xF6` | PCI programming error (driver) |

### Sending a command by hand (advanced — this changes settings)

**The commands below change live power limits on Matisse/Vermeer CPUs.** They are an example
of the mechanism, not a recommendation. They don't survive a reboot. Command IDs differ
between CPU families; `docs/rsmu_commands.md` lists the known ones.

```sh
# Write the 6 arguments (here: 142000 mW in argument 1), then the command ID (0x53 = SetPPTLimit)
printf '%0*x' 48 142000 | fold -w 2 | tac | tr -d '\n' | xxd -r -p \
  | sudo tee /sys/kernel/ryzen_smu_drv/smu_args >/dev/null
printf '\x53' | sudo tee /sys/kernel/ryzen_smu_drv/rsmu_cmd >/dev/null
od -An -tx4 /sys/kernel/ryzen_smu_drv/rsmu_cmd      # 00000001 = OK
```

Every RSMU/MP1 CPU accepts two global commands: `0x01` TestMessage (returns argument+1) and
`0x02` GetSMUVersion.

---

## 7. Reference: options

### Module parameter

| parameter | default | range | meaning |
|---|---|---|---|
| `smu_timeout_attempts` | 8192 | 500–32768 (clamped at load) | How many times the driver polls the SMU before it reports a timeout (`0xFB`). Raise it on a busy system if commands time out. |

Set it at load time, or permanently:

```sh
sudo modprobe ryzen_smu smu_timeout_attempts=16384
echo 'options ryzen_smu smu_timeout_attempts=16384' | sudo tee /etc/modprobe.d/ryzen_smu.conf
cat /sys/module/ryzen_smu/parameters/smu_timeout_attempts     # check the value in use
```

### make targets (repository root)

| target | does |
|---|---|
| `make` / `make all` / `make modules` | Build `ryzen_smu.ko` for the running kernel. |
| `make TARGET=<kernel-version>` | Build for another installed kernel. |
| `make debug` | Build with `-DDEBUG` (extra `pr_debug` output in `dmesg`). |
| `make clean` | Remove build output. |
| `sudo make dkms-install` | Copy to `/usr/src/ryzen_smu-0.1.7.raphael2` and `dkms add/build/install`. |
| `sudo make dkms-uninstall` | `dkms remove ryzen_smu/0.1.7.raphael2 --all` and delete the source copy. |
| `make insmod` | Unload any loaded copy and `insmod` the freshly built one (uses `sudo`). |
| `make checkmod` | Show `lsmod`, `/proc/modules`, `drv_version` and `modinfo` for the module. |

### monitor_cpu

| option | meaning |
|---|---|
| *(none)* | Live PM-table view (Matisse `0x240903` only on `main`; plus `0x540104` in this fork). |
| `-m` | Print DRAM timings once and exit. The register layout is the DDR4-era (Zen 2/3) one; on DDR5 platforms the values may not mean anything. |
| `-f` | Force the live view on an unsupported PM table with the Matisse layout (wrong values; a warning is printed; tables smaller than that layout are refused). |
| `-v` | Print the program version. |
| `-h` | Help (no root needed). |
| `-u<seconds>` | Refresh interval, 1–3600 seconds (default 1), e.g. `-u2` or `-u 2`. |
| `-b<MHz>` | **This fork only.** Reference clock (BCLK/eCLK) in MHz, 90–130, e.g. `-b105`. By default it is measured automatically from the TSC. The SMU reports clocks against a nominal 100 MHz, so on a BCLK-overclocked board every clock reads low by `ref/100`. |

### Scripts (`scripts/`, run with `sudo python3`)

| script | does | writes? |
|---|---|---|
| `test.py` | Version, code name, PM-table check, one SMN read. | Writes command/SMN files (harmless commands). |
| `monitor_cpu.py` | Live Matisse-layout view (FCLK/UCLK/MCLK, SoC/VDDP/VDDG voltages, cores). | Reads only. |
| `dump_pm_table.py` | 15 idle + 15 loaded dumps into `pm_dumps/`. | Starts and kills a load generator. |
| `read_dump.py` | Prints `./dump.bin` as offset → float. | No. |
| `cpuid.py` | Prints raw CPUID leaves. | No. |

---

## 8. Known limits

- **PM table layouts are not documented by AMD.** The driver hands you raw floats. Each table
  version (`0x240903`, `0x380805`, `0x540104`, `0x64010C`, ...) has its own layout, and each
  tool has to know it. Many tools know only a few.
- **Clocks on BCLK-overclocked boards read low.** The SMU never sees an external clock
  generator, so FCLK/core clocks are reported against 100 MHz.
- **Some fields are empty or constant on some CPUs.** For example, on a 7800X3D (`0x540104`),
  float 29 stays at 5.25 whatever the load (it is not socket power), and VDDG_IOD/VDDG_CCD
  read 0.
- **Commands are model-specific.** A command ID that sets PPT on Vermeer may do something else,
  or nothing, on Raphael.
- **Not persistent.** Anything you set through a command is lost at reboot or S3 resume.
- **Virtual machines.** Inside most VMs there is no SMU to talk to. The module only works on
  the host (Proxmox users: install it on the host).

---

## 9. Troubleshooting

| symptom | likely cause and fix |
|---|---|
| `modprobe: FATAL: Module ryzen_smu not found` | DKMS didn't build for this kernel. Run `dkms status`. Install the headers for `uname -r`, then `sudo dkms autoinstall`. |
| `Key was rejected by service` / `Required key not available` | Secure Boot. Sign the module with a MOK key or turn Secure Boot off. |
| `No such device` when loading | Your CPU's root complex isn't in the driver's PCI ID list (unsupported CPU), or you are in a VM. |
| `/sys/kernel/ryzen_smu_drv` missing after load | Look in `dmesg` for `Failed to initialize the SMU` / `Failed to obtain the SMU version`. Usually an unsupported or new CPU model. |
| No `pm_table` file | Your CPU has no PM table support, or `dmesg` shows `Failed to probe the PM table`. Try `smu_timeout_attempts=16384`. |
| `PM Tables are not supported on this platform` / version unsupported in monitor_cpu | Expected on anything that isn't Matisse (or `0x540104` with this fork's build). Use a tool that knows your table. |
| `monitor_cpu -f` crashes with a segfault | Older builds passed a missing "Overdrive Scalar" string to `printf` on non-Matisse CPUs. Fixed; update. `-f` values are still wrong on other tables. |
| Command reads back `0xFB` (timeout) | The SMU is busy. Raise `smu_timeout_attempts`, or retry. |
| `dmesg`: `python3: Unexpected write to kernel-exclusive config offset b8` | Newer kernels warn when a user process causes a PCI config write. The SMN access works through those registers. It is a warning, not a failure. |
| `test.py` says `Failed to detect processor code name!` | The `codename` file is missing or reads 0. Check `dmesg`. (Older copies of the script also said this on Ryzen 9000 / 8000 mobile / TR 7000 / Strix Halo because their name list was too short; that is fixed.) |
| Two DKMS entries (e.g. `0.1.7.raphael2` and `191.xxxx`) | You installed more than one of the release package, the AUR package and `make dkms-install`. Remove all but one (section 12). |
| `monitor_cpu` says the driver version is wrong | `drv_version` is not `0.1.7`: another ryzen_smu build is loaded. `sudo modprobe -r ryzen_smu && sudo modprobe ryzen_smu`, or reboot. |

---

## 10. Things that differ from the upstream README

Fixed in this fork's README, scripts and `monitor_cpu` (the driver itself is unchanged):

- sysfs files are world-readable, not root-only (section 6); the README now says so.
- The README's code-name table now includes 26 = Strix Halo.
- `scripts/test.py` used to list names only up to index 22 and label 22 "Hawk Point" (the
  driver uses 22 = Strix Point, 24 = Hawk Point); it now follows the driver.
- `monitor_cpu -u` used to be a stub and `-h` needed an argument; both work now.
- `dkms.conf` no longer contains `@VERSION@`/`@CFLGS@` placeholders, so `dkms add` works on
  the source tree directly.
- The `raphael-release` branch adds an Arch package (`packaging/`), a GitHub Actions workflow
  that builds and install-tests it in a clean Arch container, and this guide.

---

## 11. Updating

| how you installed | update with |
|---|---|
| Release package | Download the new release and `sudo pacman -U` it. The version changes with every release, so DKMS always rebuilds. |
| AUR | `yay -Syu` (or rebuild `ryzen_smu-dkms-git`). Then `sudo modprobe -r ryzen_smu && sudo modprobe ryzen_smu`, or reboot. |
| `make dkms-install` | `git pull`, then `sudo make dkms-uninstall && sudo make dkms-install`. The version string in the Makefile rarely changes, so uninstall first. Otherwise DKMS keeps the old build under the same version. |
| By hand | `git pull && make`, then reload with `make insmod`. |

Before unloading, close any program that uses the driver (monitors, fan-control or tuning
daemons, system-info tools). Rebooting is the simplest option.

## 12. Uninstall

```sh
# release package
sudo pacman -R ryzen_smu-raphael-dkms
# AUR
sudo pacman -R ryzen_smu-dkms-git
# make dkms-install
sudo make dkms-uninstall
# auto-load and options files, if you created them
sudo rm -f /etc/modules-load.d/ryzen_smu.conf /etc/modprobe.d/ryzen_smu.conf
```

Then reboot, or `sudo modprobe -r ryzen_smu` once nothing is using it.

---

## 13. FAQ

**Is it safe?** Loading it and reading values is safe. It is the same kind of access that
Windows monitoring tools use. Writing commands is where the risk is.

**Does it overclock my CPU?** Not by itself. It only gives programs a way to send commands.

**Why does `sensors` not show these values?** `k10temp` exposes only a few temperatures.
The PM table holds far more, but only through the SMU.

**Do I need the fork, or is the AUR package enough?** For the driver, the AUR package is enough.
It is the same code. You only need this fork for the `0x540104` monitor_cpu view and the
other monitor_cpu fixes.

**Can a normal user read the PM table?** With this driver, yes (the files are world-readable).
Some tools still insist on root.

**Does it work on Intel or on AMD GPUs?** No. Only AMD Zen CPUs and APUs (the APU's integrated
GPU shares the SMU, but this is not a GPU driver).

---

## 14. Glossary

- **SMU** — System Management Unit. A small processor inside the CPU that runs AMD firmware for
  power, clocks and temperature management.
- **MP1 / RSMU / HSMP** — three "mailboxes" (message channels) into the SMU. MP1 exists on all
  supported CPUs. RSMU is the one Ryzen Master uses for most tuning. HSMP is for
  server/workstation parts.
- **Mailbox command** — a command ID plus up to six 32-bit arguments; the SMU replies with a
  status and up to six results.
- **PM table** — Power/Performance Metrics table. A block of floats the SMU copies to memory with
  live sensor readings. Its layout is identified by the **PM table version**.
- **SMN** — System Management Network. The internal address space of AMD's on-chip registers
  (memory controller, fabric, and more).
- **AGESA** — AMD's firmware code inside your BIOS. The SMU firmware version changes with it.
- **PPT / TDC / EDC** — package power limit (watts), sustained current limit and peak current
  limit (amps).
- **PBO** — Precision Boost Overdrive, AMD's automatic boost-limit extension.
- **FCLK / UCLK / MCLK** — Infinity Fabric clock, memory-controller clock and memory clock.
- **VID** — Voltage ID, the voltage the CPU requests.
- **BCLK / eCLK** — base (reference) clock, normally 100 MHz. Some boards let you raise it with
  an external clock generator.
- **TSC** — Time Stamp Counter, a CPU counter at a fixed rate. Used by this fork's monitor_cpu to measure the
  real reference clock.
- **DKMS** — Dynamic Kernel Module Support. Rebuilds out-of-tree modules automatically when you
  install a new kernel.
- **sysfs** — the `/sys` virtual filesystem through which drivers expose files.
- **Taint** — a kernel flag recording that an out-of-tree or unsigned module was loaded. It is
  informational.
- **MOK** — Machine Owner Key, your own Secure Boot signing key.

---

## 15. Credits and licence

- **Leonardo Gates (leogx9r)** — original author of ryzen_smu (gitlab.com/leogx9r/ryzen_smu).
- **amkillam and contributors** — current upstream (github.com/amkillam/ryzen_smu): merged
  fixes, new CPU support (Strix Point, Strix Halo, Granite Ridge and others), kernel
  compatibility.
- **This fork** (Eugene Flanagin) — tracks upstream `main`; adds the `0x540104` monitor_cpu,
  the fixes listed in section 10, the Arch package and this guide. See `CREDITS.md`.
- The starting offsets for the `0x540104` layout were cross-checked against the open-source
  TuxTimings project. The mapping on the branch was measured independently on real hardware.

Licences: the kernel driver is **GPL-2.0** (`LICENSE`). The userspace library in `lib/` is
**GPL-3.0** (`lib/LICENSE`).

AMD, Ryzen, Threadripper, EPYC, Ryzen Master and AGESA are trademarks of Advanced Micro Devices,
Inc. This project is not affiliated with, endorsed by, or supported by AMD. Use at your own
risk.
