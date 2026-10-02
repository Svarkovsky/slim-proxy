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

## Two variants: `wg` and `lowmem`

Every architecture is built in two variants. They share the same code and
config format and differ only in what is compiled in.

| | `wg` | `lowmem` |
|---|---|---|
| Built-in WireGuard endpoint | yes (userspace, gVisor) | no |
| Per-connection buffers | 32 KB | 16 KB |
| Binary size (mips) | ~23.7 MB | ~19.5 MB |
| RAM at idle (measured) | ~20 MB | ~14–17 MB |

**Why two variants?** WireGuard needs a userspace network stack (gVisor)
when the kernel has no WireGuard module and no TUN device, which is common
on stock router firmware. That stack is the largest part of the binary.
If the tunnel is already provided by the system (or you do not need one),
there is no reason to carry it, so `lowmem` drops it and also halves the
I/O buffers.

**Which one to pick:**
- **`wg`**: the program itself must bring up the WireGuard tunnel.
- **`lowmem`**: the program only dispatches traffic between `direct`
  outbounds (for example, bound to different local addresses or
  interfaces), `block`/`reject` and DoH. A "smart traffic router".

A WireGuard config will not start on `lowmem`; it fails with
`WireGuard is not included in this build`.

### Base config for `wg`

Full file: [examples/wg.json](examples/wg.json). Selected domains go
through the WireGuard tunnel, everything else goes direct.

```json
{
  "log": { "level": "warn", "timestamp": true },
  "dns": {
    "servers": [
      { "type": "local", "tag": "local" },
      { "type": "https", "tag": "doh", "server": "1.1.1.1" }
    ],
    "final": "doh",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    { "type": "mixed", "tag": "in", "listen": "0.0.0.0", "listen_port": 1080 }
  ],
  "endpoints": [
    {
      "type": "wireguard",
      "tag": "wg",
      "mtu": 1280,
      "address": ["10.0.0.2/32"],
      "private_key": "YOUR_PRIVATE_KEY",
      "peers": [
        {
          "address": "203.0.113.10",
          "port": 51820,
          "public_key": "PEER_PUBLIC_KEY",
          "allowed_ips": ["0.0.0.0/0", "::/0"]
        }
      ]
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "default_domain_resolver": { "server": "local" },
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "action": "route", "outbound": "direct" },
      { "domain_suffix": ["example.com", "example.org"], "action": "route", "outbound": "wg" }
    ],
    "final": "direct"
  }
}
```

### Base config for `lowmem`

Full file: [examples/lowmem.json](examples/lowmem.json). Selected domains
leave through a `direct` outbound bound to another local address (for
example, an existing system tunnel), some domains get TLS fragmentation,
DNS goes over DoH.

```json
{
  "log": { "level": "warn", "timestamp": true },
  "dns": {
    "servers": [
      { "type": "local", "tag": "local" },
      { "type": "https", "tag": "doh", "server": "1.1.1.1", "tls": { "enabled": true, "fragment": true } }
    ],
    "final": "doh",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    { "type": "mixed", "tag": "in", "listen": "0.0.0.0", "listen_port": 1080 }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "direct", "tag": "via-tunnel", "inet4_bind_address": "10.0.0.2" }
  ],
  "route": {
    "default_domain_resolver": { "server": "doh", "strategy": "ipv4_only" },
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      { "ip_is_private": true, "action": "route", "outbound": "direct" },
      { "network": "udp", "port": [135, 137, 138, 139, 5353], "action": "reject" },
      { "domain_suffix": ["example.com", "example.org"], "action": "route", "outbound": "via-tunnel" },
      { "domain_suffix": ["youtube.com", "googlevideo.com", "ytimg.com"], "action": "route", "outbound": "direct", "tls_fragment": true }
    ],
    "final": "direct"
  }
}
```

Replace the addresses, keys, port and domain lists with your own. If
`tls_fragment` does not help, try `tls_record_fragment` (for the DoH
server: `record_fragment`), or enable both.

## Which file to download

Files are in **Releases**. File name: `slim-proxy-1.14.2-<variant>-linux-<arch>`,
where `<variant>` is `wg` or `lowmem` (see above).

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
