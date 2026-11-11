<div align="center">

# 🎵 Your Own Local Spotify on Proxmox

### Self-hosted music streaming with Navidrome + spotDL

[📖 Web guide (ES/EN)](https://serverheaven.github.io/guia-spotify-lolcal-proxmox/) · [🇪🇸 README en español](README.md)

</div>

---

> This is the English summary of the [Spanish README](README.md). The full step-by-step guide is the web page (`index.html`), which has an **ES / EN** switch (also `?lang=en`).

## What is this

A guide to run your own Spotify-like server on a Proxmox LXC container:

| Component | Role |
|:--|:--|
| **[Navidrome](https://www.navidrome.org/)** | Open-source streaming server, multi-user, Subsonic API (40+ client apps) |
| **[spotDL](https://github.com/spotDL/spotify-downloader)** | CLI that finds songs on YouTube from Spotify metadata; `sync` keeps playlists up to date |
| **Docker Compose** | Runs Navidrome inside the LXC |
| **Tailscale** (optional) | Private remote access without opening ports |

```
Proxmox VE → LXC (Debian 12 + Docker) → Navidrome :4533 ← /music ← spotDL + cron
                                                   ↑ clients: Symfonium, play:Sub, Feishin, web...
```

## Requirements

- Proxmox VE 8.x or later (7.x is no longer supported) and SSH access to the host
- Container: 1–2 cores, 1–2 GB RAM, 16–20 GB disk (+ storage for your music)
- Internet access from the container

## Quick start

```bash
# 1. On the Proxmox host: create the LXC
#    (check the exact template name with: pveam update && pveam available --section system)
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname navidrome --memory 1024 --cores 2 \
  --rootfs local-lvm:16 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features keyctl=1,nesting=1 --unprivileged 1 --start 1

# 2. Inside the container: install Docker
pct enter 200
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh

# 3. Directories
mkdir -p /opt/navidrome/data /mnt/music/Playlists /opt/spotdl /var/log/spotdl

# 4. Create /opt/navidrome/docker-compose.yml (full file in the Spanish README / web guide):
#    image deluan/navidrome:latest, port 4533,
#    volumes /opt/navidrome/data:/data and /mnt/music:/music:ro,
#    ND_SCANNER_SCHEDULE: "@every 15m"  (older versions: ND_SCANSCHEDULE)
cd /opt/navidrome && docker compose up -d

# 5. spotDL
apt install -y python3 python3-pip ffmpeg
pip3 install spotdl --break-system-packages

# 6. Master sync script + cron (3 AM)
curl -o /opt/spotdl/sync-all.sh \
  https://raw.githubusercontent.com/ServerHeaven/guia-spotify-lolcal-proxmox/main/scripts/sync-all.sh
chmod +x /opt/spotdl/sync-all.sh
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/spotdl/sync-all.sh >> /var/log/spotdl/sync.log 2>&1") | crontab -
```

Open **http://CONTAINER-IP:4533** and create the admin user.

## ⚠️ Known limitations

- **Spotify-owned playlists (the official "Top 50"s)**: since 27 Nov 2024 the Spotify Web API returns `404` for these to apps without an extended quota ([Spotify announcement](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api)). spotDL queries that API, so syncing the official Top 50 URLs may fail. Test one URL first; otherwise use public user-made playlists that mirror the charts, or your own playlists.
- **Tailscale in an unprivileged LXC** needs the TUN device: on the host run `pct set 200 --dev0 /dev/net/tun` and `pct set 200 --features keyctl=1,nesting=1` ([docs](https://tailscale.com/kb/1130/lxc-unprivileged)). HTTPS: `tailscale serve --bg 4533`.
- `ND_SPOTIFY_ID` / `ND_SPOTIFY_SECRET` were removed in Navidrome 0.61; use Last.fm or Deezer for metadata.

## Troubleshooting

| Problem | Fix |
|:--|:--|
| No new music | Wait for the scan or trigger one manually (admins) |
| spotDL 404 on a Top 50 | See the limitation above |
| spotDL 403 | YouTube rate-limit: wait, or use `--audio youtube-music` |
| Docker won't start in the LXC | `pct set 200 --features keyctl=1,nesting=1` |
| Permission errors | Adjust ownership of `/mnt/music` or the `user:` in the compose file |

## Legal

spotDL downloads audio from YouTube, not Spotify. Respect the copyright laws of your country; intended for personal use. The Spanish README states an MIT license, but the `LICENSE` file it links to is not present in the repository.
