---
name: reset-openvpn-connect
description: Force-quit a stuck macOS OpenVPN Connect client and reset its hijacked routing/utun state so the user can reconnect. Use when the user reports OpenVPN Connect is stuck on "Trying to connect", connection hangs, the VPN suddenly stopped working, host became unreachable while the app is running, leftover utun interfaces, or any symptom suggesting OpenVPN Connect on macOS has wedged itself.
---

# Reset OpenVPN Connect (macOS)

A recovery procedure for the macOS **OpenVPN Connect** client (v3.x) when it gets stuck in `Trying to connect…` or otherwise wedges the local network stack (hijacked/orphaned routes, accumulated `utun` interfaces, outbound packets dropped before they reach the NIC, `Network is unreachable` errors on otherwise-working interfaces).

## When to Use

Trigger this skill when the user reports any of:

- OpenVPN Connect stuck on "Trying to connect…" with no progress
- VPN that "was working until today" suddenly fails to connect
- Outbound traffic to specific IPs fails with `Network is unreachable` or silent drops while general internet works
- Multiple `utun` interfaces accumulated (more than the usual 3–4 macOS system ones)
- The OpenVPN Connect window has been closed but the app is still affecting the network
- User says they "quit" OpenVPN Connect but the symptoms persist

## Why This Happens

OpenVPN Connect on macOS is a v3.x Electron app, but the persistence isn't really about the GUI — it's about **two root-privileged LaunchDaemons** that run independently of the user-facing app:

- `/Library/LaunchDaemons/org.openvpn.connect.agent.plist` → `ovpnagent`
- `/Library/LaunchDaemons/org.openvpn.connect.helper.plist` → `ovpnhelper`

Both auto-restart via `launchd` after a plain `killall`. They survive `Cmd+Q` on the GUI. They are the components that own the VPN tunnel and the routing table changes.

Two common wedge modes:

1. **Disconnect leaves bad routes.** OpenVPN has a long-standing class of bugs where the disconnect path removes routes from the wrong interface or fails to clean up host routes. The default route ends up pointing at a stale or non-functional `utun`.
2. **Accumulated `utun` interfaces cause socket-binding ambiguity.** macOS's `NetworkExtension` framework leaks `utun` interfaces (they cannot be destroyed from userspace — `ifconfig utunN destroy` returns `SIOCIFDESTROY: Invalid argument`). Reports of 90+ leaked `utun`s exist. When the kernel can't unambiguously choose a source address/interface for a new outbound socket, `sendto()` returns `Network is unreachable` — even for traffic unrelated to the VPN.

## Diagnostic Signals

Before applying the reset, confirm with these quick checks. If multiple match, this skill is the right fix:

```bash
# 1. Are OpenVPN daemons running?
ps -ax | grep -iE "openvpn|ovpnagent|ovpnhelper" | grep -v grep

# 2. How many utun interfaces? (macOS baseline is usually 3–4; 6+ is suspicious, 10+ is almost certainly leaked)
ifconfig -l | tr ' ' '\n' | grep -c '^utun'

# 3. Does outbound UDP to a known-reachable IP fail unexpectedly?
python3 -c "import socket; s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(2); print(s.sendto(b'x', ('8.8.8.8', 53)))"

# 4. Are the LaunchDaemons loaded?
sudo launchctl list | grep -i openvpn
```

Red flags: `ovpnagent`/`ovpnhelper` running, 6+ `utun` interfaces, `sendto()` raises `Network is unreachable`, daemons listed in `launchctl list`.

> Do **not** treat a `192.0.0.1` default gateway as a red flag on its own — that's the normal gateway for iPhone USB tethering / Personal Hotspot, not a hijacked route.

## The Fix

### Step 1 — Unload the LaunchDaemons (not just `killall`)

Plain `killall` is insufficient because `launchd` will respawn `ovpnagent`/`ovpnhelper` within seconds. Unload them first, then kill any stragglers:

```bash
sudo launchctl unload /Library/LaunchDaemons/org.openvpn.connect.agent.plist 2>/dev/null
sudo launchctl unload /Library/LaunchDaemons/org.openvpn.connect.helper.plist 2>/dev/null

sudo killall -9 "OpenVPN Connect" "OpenVPN Connect Helper" \
  "OpenVPN Connect Helper (GPU)" "OpenVPN Connect Helper (Renderer)" \
  ovpnagent ovpnhelper 2>/dev/null
```

The Electron helper names follow Chromium conventions and may vary slightly between versions; `killall` ignores names it doesn't find, so listing all of them is safe. Verify nothing OpenVPN-related is still running:

```bash
ps -ax | grep -iE "openvpn|ovpnagent|ovpnhelper" | grep -v grep
# expected: no output
```

To restore the daemons after a successful reconnect later (or after a reboot which reloads them automatically):

```bash
sudo launchctl load /Library/LaunchDaemons/org.openvpn.connect.agent.plist
sudo launchctl load /Library/LaunchDaemons/org.openvpn.connect.helper.plist
```

### Step 2 — (Recommended) Reboot the Mac

Reboot is the **only reliable way** to clear leaked `utun` interfaces. They are kernel-managed via `NetworkExtension` and cannot be destroyed from userspace. Stale host routes installed by OpenVPN can also survive a process kill.

If the user refuses to reboot, the safest partial-cleanup is to cycle the network service rather than flushing the route table:

```bash
networksetup -setnetworkserviceenabled Wi-Fi off
sleep 2
networksetup -setnetworkserviceenabled Wi-Fi on
```

(Substitute `Ethernet` or the actual service name from `networksetup -listallnetworkservices` if not on Wi-Fi.)

> **Do not run `sudo route -n flush`.** It nukes every route including the working default, frequently disconnects the active network service, and on some macOS versions requires another reboot to recover. The `networksetup` cycle above is the safe substitute.

After the cycle, re-check `ifconfig -l | grep -c '^utun'`. If it still shows the leaked count, a reboot is unavoidable.

### Step 3 — Reopen OpenVPN Connect and reconnect

Launch the app fresh and click **Connect**. The LaunchDaemons will be reloaded automatically (either by the app at launch or after the reboot). It should now negotiate normally.

## Important Notes

- **`Disconnect` in the GUI is not enough** when the client is wedged. The daemons must be unloaded.
- **`Cmd+Q` is not enough either** — it quits the Electron GUI but leaves `launchd` running both daemons.
- **Don't troubleshoot the VPN server first** when these client-side signals are present. A wedged client looks identical to a server outage from the user's perspective — same "can't connect" UX — but is a 30-second fix on the client side. Verify client state before chasing server-side causes.
- **Same-NAT (hairpin NAT loopback) trap:** if the user is on the same network as the VPN server and the router does not support NAT loopback, connection attempts will fail. Repeated failed retries in this state can combine with the `utun`/route bugs above to leave the client wedged. Suggest connecting to the VPN server's LAN IP directly (via `Server Override` in the profile settings) or only using the VPN from external networks.
