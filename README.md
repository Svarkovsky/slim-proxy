# slim-proxy

Slim static builds of a proxy based on the
[sing-box](https://github.com/SagerNet/sing-box) **v1.14.2** source code,
for routers and other low-resource devices.

> This is an **unofficial** build. It is not affiliated with or endorsed by
> the sing-box authors. The sing-box license does not allow derivative works
> to use its name, so this project uses a different one.

## Why

The stock sing-box 1.14.2 build is about 44 MB. It includes dozens of
protocols, a gRPC API, Tailscale, OpenVPN and more. That is too much for a
router with 64–128 MB of RAM and a small flash chip.

These builds keep only what a "smart traffic router" needs:

| Included | Removed |
|---|---|
| Inbounds: `mixed` (SOCKS5 + HTTP), `socks` | tun, redirect/tproxy |
| Outbounds: `direct`, `block` | shadowsocks, vmess, vless, trojan, hysteria, etc. |
| Endpoint: `wireguard` (`wg` variant only) | tailscale, openvpn, openconnect |
| DNS: local, udp, tcp, tls (DoT), https (DoH) | DoQ/DoH3, DHCP, fakeip, mDNS |
| Routing rules, rule-sets, TLS fragmentation | API, Clash API, services |
| Commands: `run`, `check`, `format`, `version` | `api`, `tools`, `geoip`, `rule-set`, etc. |

## Which file to download

Files are in **Releases**. File name: `slim-proxy-1.14.2-<variant>-linux-<arch>`.

**Variant:**
- `wg`: with built-in WireGuard (userspace, via gVisor). Use it when the
  program itself brings up the WireGuard tunnel and the kernel has no
  WireGuard module.
- `lowmem`: no WireGuard, smaller buffers. Use it when the program only
  dispatches traffic to `direct` and `block`. About 4 MB smaller and uses
  less RAM.

**Architecture:**

| Arch | Devices |
|---|---|
| `mips` | MIPS big-endian: Qualcomm Atheros (QCA95xx), e.g. ASUS RT-AC57U V3 |
| `mipsle` | MIPS little-endian: MediaTek/Ralink MT7620, MT7621, MT7628 (Xiaomi, Keenetic, TP-Link) |
| `armv7` | 32-bit ARM: older Raspberry Pi boards, Cortex-A7 routers |
| `arm64` | 64-bit ARM: Raspberry Pi 3/4/5, Cortex-A53/A72 routers |
| `amd64` | Standard x86_64 PCs, servers, VPS |

All binaries are fully static (no libc), so they work with musl, glibc or
uClibc alike. Linux kernel **3.2 or newer** is required.

Not sure about your architecture? Run `uname -m` and
`grep -m1 -i endian /proc/cpuinfo 2>/dev/null` on the device.

## Usage

```sh
chmod +x slim-proxy-1.14.2-lowmem-linux-mipsle
./slim-proxy-1.14.2-lowmem-linux-mipsle check -c config.json
./slim-proxy-1.14.2-lowmem-linux-mipsle run -c config.json
```

The configuration format is the same as sing-box 1.14:
[sing-box documentation](https://sing-box.sagernet.org/configuration/).

Router tips:
- Do not compress the binary with UPX: it is fully unpacked into RAM at
  startup, so it uses more memory, not less.
- If possible, keep the binary on USB storage or `/jffs` rather than `/tmp`
  (`/tmp` lives in RAM).

## Building

Builds run automatically in GitHub Actions: **Actions** → **build** →
**Run workflow**. After a few minutes the files appear in **Releases**.

Manual build (requires Go 1.26+):

```sh
./build.sh lowmem mipsle    # variant and architecture
./build.sh source           # source archive with the patch applied
```

What the build does: downloads the sing-box v1.14.2 source, replaces
`include/registry.go` (keeping only the needed protocols) and adds a
lightweight command line in `cmd/lite`. All changes are in the `patch/`
folder.

## Disclaimer

This software is provided **"as is", without warranty of any kind**,
express or implied, including but not limited to the warranties of
merchantability and fitness for a particular purpose. You use it entirely
at your own risk. The author of these builds is not liable for any damage,
data loss, device malfunction or other consequences of its use, nor for
your compliance with the laws of your country. Do not send issues about
these builds to the sing-box authors: they are unofficial.

## License

Like the upstream project, this is distributed under the
**GNU GPL v3.0 or later**, with the additional term set by the sing-box
author: see [LICENSE](LICENSE) and the full GPL text in [COPYING](COPYING).

Upstream source: sing-box © 2022 nekohasekai,
<https://github.com/SagerNet/sing-box>. The changes in `patch/` and the
build scripts are distributed under the same terms. The complete
corresponding source code is attached to every release
(`slim-proxy-1.14.2-source.tar.gz`).
