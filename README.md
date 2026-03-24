<div align="center">

# 🎵 Tu Propio Spotify Local en Proxmox

### Servidor de streaming musical autoalojado con Navidrome + spotDL

[![Proxmox](https://img.shields.io/badge/Proxmox-VE%207%2B-E57000?style=for-the-badge&logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![Navidrome](https://img.shields.io/badge/Navidrome-Latest-1DB954?style=for-the-badge&logo=spotify&logoColor=white)](https://www.navidrome.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![spotDL](https://img.shields.io/badge/spotDL-v4.x-FF6B6B?style=for-the-badge&logo=python&logoColor=white)](https://github.com/spotDL/spotify-downloader)
[![License](https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge)](LICENSE)

<br>

<img src="https://raw.githubusercontent.com/navidrome/navidrome/master/.github/screenshots/ss-desktop-player.png" alt="Navidrome Screenshot" width="700">

<br>

**Monta tu propio servidor de música tipo Spotify, 100% local, sin suscripciones y sin rastreo.**
**Descarga automática de las listas más escuchadas de EE.UU., España, México y más.**

[📖 Guía Completa](#-guía-paso-a-paso) · [⚡ Inicio Rápido](#-inicio-rápido) · [🎯 URLs Top 50](#-urls-oficiales-de-playlists-top-50) · [❓ FAQ](#-solución-de-problemas)

</div>

-----

## 📋 Tabla de Contenidos

- [Qué es esto](#-qué-es-esto)
- [Arquitectura](#-arquitectura)
- [Requisitos](#-requisitos)
- [Inicio Rápido](#-inicio-rápido)
- [Guía Paso a Paso](#-guía-paso-a-paso)
  - [1. Crear Contenedor LXC](#1-crear-contenedor-lxc-en-proxmox)
  - [2. Instalar Docker](#2-instalar-docker)
  - [3. Desplegar Navidrome](#3-desplegar-navidrome)
  - [4. Instalar spotDL](#4-instalar-spotdl)
  - [5. Automatizar Descargas](#5-automatizar-descargas-con-cron)
  - [6. Script Maestro](#6-script-maestro-de-sincronización)
  - [7. Acceso Remoto](#7-acceso-remoto-con-tailscale)
- [URLs Oficiales de Playlists Top 50](#-urls-oficiales-de-playlists-top-50)
- [Clientes Compatibles](#-clientes-compatibles)
- [Mantenimiento](#-mantenimiento)
- [Solución de Problemas](#-solución-de-problemas)
- [Contribuir](#-contribuir)
- [Licencia](#-licencia)

-----

## 🤔 Qué es esto

Este repositorio es una **guía completa** para montar tu propio servidor de streaming musical (tipo Spotify) en un servidor Proxmox, combinando:

|Componente                                                |Función                                                                                                               |
|:---------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------|
|**[Navidrome](https://www.navidrome.org/)**               |Servidor de streaming open source. Interfaz web moderna, multi-usuario, compatible con API Subsonic (40+ apps móviles)|
|**[spotDL](https://github.com/spotDL/spotify-downloader)**|Descarga música de YouTube usando metadatos de Spotify. Incluye carátulas, letras y metadatos completos               |
|**Cron + Script Bash**                                    |Automatiza la descarga diaria de las playlists Top 50 de múltiples países                                             |
|**[Tailscale](https://tailscale.com/)**                   |VPN mesh para acceso remoto seguro sin abrir puertos                                                                  |

### ¿Por qué?

- 🚫 Sin suscripciones mensuales
- 🔒 Sin rastreo ni publicidad
- 📱 Acceso desde cualquier dispositivo (web, Android, iOS, escritorio)
- 🔄 Las listas más populares se actualizan automáticamente cada noche
- 🏠 Todo corre en tu propio hardware

-----

## 🏗 Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                   PROXMOX VE (Host)                 │
│  ┌───────────────────────────────────────────────┐  │
│  │          Contenedor LXC (Debian 12)           │  │
│  │  ┌─────────────┐  ┌────────────────────────┐  │  │
│  │  │   Docker     │  │      spotDL + Cron     │  │  │
│  │  │ ┌─────────┐  │  │  Descarga automática   │  │  │
│  │  │ │Navidrome│  │  │  de playlists Top 50   │  │  │
│  │  │ │ :4533   │  │  └──────────┬─────────────┘  │  │
│  │  │ └────┬────┘  │             │                 │  │
│  │  └──────┼───────┘             │                 │  │
│  │         └──────────┬──────────┘                 │  │
│  │                    ▼                            │  │
│  │            📁 /mnt/music                        │  │
│  │         (volumen compartido)                    │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │ Tailscale VPN / LAN
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   📱 Móvil      💻 Escritorio   🌐 Web
  Symfonium       Feishin       Navegador
  play:Sub      Sublime Music
```

-----

## 📦 Requisitos

### Hardware

|Componente    |Mínimo         |Recomendado      |
|:-------------|:--------------|:----------------|
|CPU           |1 core         |2 cores          |
|RAM           |512 MB         |1-2 GB           |
|Disco (SO)    |8 GB           |20 GB            |
|Disco (música)|Según colección|500 GB+ (HDD/NAS)|

### Software

- ✅ Proxmox VE 7.x o superior
- ✅ Acceso SSH al host
- ✅ Conexión a internet en el contenedor

-----

## ⚡ Inicio Rápido

> Para quienes ya tienen experiencia con Proxmox y Docker. Si prefieres la guía detallada, salta a la [siguiente sección](#-guía-paso-a-paso).

```bash
# 1. Crear contenedor LXC en Proxmox
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname navidrome --memory 1024 --cores 2 \
  --rootfs local-lvm:16 --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --features nesting=1 --unprivileged 1 --start 1

# 2. Entrar al contenedor e instalar Docker
pct enter 200
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh

# 3. Crear directorios
mkdir -p /opt/navidrome/data /mnt/music/Playlists /opt/spotdl /var/log/spotdl

# 4. Crear docker-compose.yml
cat > /opt/navidrome/docker-compose.yml << 'EOF'
services:
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    user: "0:0"
    ports:
      - "4533:4533"
    restart: unless-stopped
    environment:
      ND_SCANSCHEDULE: 15m
      ND_LOGLEVEL: info
      ND_SESSIONTIMEOUT: 72h
      ND_ENABLETRANSCODING: "true"
      ND_ENABLEDOWNLOADS: "true"
      ND_DEFAULTLANGUAGE: es
    volumes:
      - "/opt/navidrome/data:/data"
      - "/mnt/music:/music:ro"
EOF

# 5. Levantar Navidrome
cd /opt/navidrome && docker compose up -d

# 6. Instalar spotDL
apt install -y python3 python3-pip ffmpeg
pip3 install spotdl --break-system-packages

# 7. Descargar el script maestro
curl -o /opt/spotdl/sync-all.sh \
  https://raw.githubusercontent.com/ServerHeaven/guia-spotify-lolcal-proxmox/main/scripts/sync-all.sh
chmod +x /opt/spotdl/sync-all.sh

# 8. Configurar cron (ejecutar cada noche a las 3 AM)
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/spotdl/sync-all.sh >> /var/log/spotdl/sync.log 2>&1") | crontab -

# 9. Primera sincronización manual
/opt/spotdl/sync-all.sh
```

Accede a **http://IP-DEL-CONTENEDOR:4533** y crea tu usuario admin. 🎉

-----

## 📖 Guía Paso a Paso

### 1. Crear Contenedor LXC en Proxmox

#### Opción A: Interfaz Web

1. Abre `https://tu-ip-proxmox:8006`
1. Descarga el template de **Debian 12** desde el repositorio
1. Crea un nuevo CT con estos parámetros:

|Parámetro  |Valor                                   |
|:----------|:---------------------------------------|
|Hostname   |`navidrome`                             |
|Template   |`debian-12-standard`                    |
|Disco raíz |`16 GB`                                 |
|CPU        |`2 cores`                               |
|Memoria    |`1024 MB`                               |
|Swap       |`512 MB`                                |
|Red        |`DHCP o IP estática`                    |
|**Nesting**|**✅ Habilitado** (necesario para Docker)|

#### Opción B: Línea de Comandos

```bash
# Descargar template
pveam download local debian-12-standard_12.7-1_amd64.tar.zst

# Crear contenedor
pct create 200 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname navidrome \
  --memory 1024 --swap 512 \
  --cores 2 \
  --rootfs local-lvm:16 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.50/24,gw=192.168.1.1 \
  --features nesting=1 \
  --unprivileged 1 \
  --start 1
```

> [!TIP]
> Usa IP estática para acceder siempre a Navidrome en la misma dirección.

#### Montar almacenamiento externo (NAS)

```bash
# En el host Proxmox, editar config del CT
nano /etc/pve/lxc/200.conf

# Agregar:
mp0: /mnt/nas/music,mp=/mnt/music
```

-----

### 2. Instalar Docker

```bash
# Entrar al contenedor
pct enter 200

# Actualizar
apt update && apt upgrade -y

# Instalar dependencias
apt install -y ca-certificates curl gnupg lsb-release

# Repositorio oficial Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar
apt update
apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Verificar
docker --version
docker compose version
```

> [!NOTE]
> Si usas Ubuntu, cambia `debian` por `ubuntu` en la URL del repositorio.

-----

### 3. Desplegar Navidrome

```bash
# Crear directorios
mkdir -p /opt/navidrome/data /mnt/music
```

Crea el archivo `docker-compose.yml`:

```yaml
# /opt/navidrome/docker-compose.yml
services:
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    user: "0:0"
    ports:
      - "4533:4533"
    restart: unless-stopped
    environment:
      ND_SCANSCHEDULE: 15m
      ND_LOGLEVEL: info
      ND_SESSIONTIMEOUT: 72h
      ND_ENABLETRANSCODING: "true"
      ND_TRANSCODINGCACHESIZE: 1GB
      ND_ENABLESHARING: "true"
      ND_ENABLEDOWNLOADS: "true"
      ND_DEFAULTLANGUAGE: es
    volumes:
      - "/opt/navidrome/data:/data"
      - "/mnt/music:/music:ro"
```

```bash
# Levantar
cd /opt/navidrome
docker compose up -d

# Verificar
docker compose ps
docker compose logs -f navidrome
```

Accede a **http://IP:4533** y crea tu usuario administrador.

> [!IMPORTANT]
> `ND_SCANSCHEDULE: 15m` hace que la música nueva aparezca rápido. Ajusta a `1h` si prefieres menos carga.

#### Variables de configuración útiles

|Variable                  |Descripción                                      |
|:-------------------------|:------------------------------------------------|
|`ND_SCANSCHEDULE`         |Frecuencia de escaneo (`15m`, `1h`, `@every 30m`)|
|`ND_ENABLETRANSCODING`    |Transcodificación al vuelo                       |
|`ND_ENABLESHARING`        |Compartir enlaces públicos                       |
|`ND_ENABLEDOWNLOADS`      |Descargas desde la interfaz                      |
|`ND_DEFAULTLANGUAGE`      |Idioma (`es`, `en`, `pt`)                        |
|`ND_LASTFM_APIKEY`        |Scrobbling con Last.fm                           |
|`ND_SPOTIFY_ID` / `SECRET`|Carátulas desde Spotify                          |

-----

### 4. Instalar spotDL

[spotDL](https://github.com/spotDL/spotify-downloader) busca canciones en YouTube a partir de metadatos de Spotify y las descarga con carátulas, letras y metadatos completos.

```bash
# Instalar Python y dependencias
apt install -y python3 python3-pip ffmpeg

# Instalar spotDL
pip3 install spotdl --break-system-packages

# Verificar
spotdl --version
```

#### Uso básico

```bash
# Descargar una canción
spotdl download "https://open.spotify.com/track/ID_CANCION"

# Descargar playlist con estructura de carpetas
spotdl download "https://open.spotify.com/playlist/ID_PLAYLIST" \
  --output "/mnt/music/{artist}/{album}/{title}.{output-ext}"
```

#### Función SYNC (clave para automatización)

La función `sync` compara la playlist actual con lo descargado: baja las nuevas y elimina las que ya no están.

```bash
# Primera vez: crear archivo de sincronización
spotdl sync "URL_PLAYLIST" \
  --save-file "/opt/spotdl/nombre.sync.spotdl" \
  --output "/mnt/music/Playlists/Nombre/{title}.{output-ext}"

# Ejecuciones posteriores: solo actualizar
spotdl sync "/opt/spotdl/nombre.sync.spotdl"
```

> [!TIP]
> `sync` no re-descarga toda la playlist. Solo baja las nuevas y elimina las que se quitaron. Perfecto para playlists que cambian semanalmente.

-----

### 5. Automatizar Descargas con Cron

```bash
# Crear directorios
mkdir -p /opt/spotdl /mnt/music/Playlists /var/log/spotdl
```

Inicializar sincronizaciones (ejecutar una vez):

```bash
# Top 50 Global
spotdl sync "https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF" \
  --save-file "/opt/spotdl/top50-global.sync.spotdl" \
  --output "/mnt/music/Playlists/Top50-Global/{title}.{output-ext}"

# Top 50 USA
spotdl sync "https://open.spotify.com/playlist/37i9dQZEVXbLRQDuF5jeBp" \
  --save-file "/opt/spotdl/top50-usa.sync.spotdl" \
  --output "/mnt/music/Playlists/Top50-USA/{title}.{output-ext}"

# Top 50 España
spotdl sync "https://open.spotify.com/playlist/37i9dQZEVXbNFJfN1Vw8d9" \
  --save-file "/opt/spotdl/top50-spain.sync.spotdl" \
  --output "/mnt/music/Playlists/Top50-Spain/{title}.{output-ext}"

# Top 50 México
spotdl sync "https://open.spotify.com/playlist/37i9dQZEVXbO3qyFxbkOE1" \
  --save-file "/opt/spotdl/top50-mexico.sync.spotdl" \
  --output "/mnt/music/Playlists/Top50-Mexico/{title}.{output-ext}"
```

Configurar cron (`crontab -e`):

```cron
# Sincronizar playlists Top 50 cada día a las 3 AM (escalonadas)
0  3 * * *  /usr/local/bin/spotdl sync /opt/spotdl/top50-global.sync.spotdl >> /var/log/spotdl/global.log 2>&1
15 3 * * *  /usr/local/bin/spotdl sync /opt/spotdl/top50-usa.sync.spotdl    >> /var/log/spotdl/usa.log 2>&1
30 3 * * *  /usr/local/bin/spotdl sync /opt/spotdl/top50-spain.sync.spotdl  >> /var/log/spotdl/spain.log 2>&1
45 3 * * *  /usr/local/bin/spotdl sync /opt/spotdl/top50-mexico.sync.spotdl >> /var/log/spotdl/mexico.log 2>&1
```

> [!TIP]
> Las descargas están escalonadas cada 15 minutos para evitar throttling de YouTube.

-----

### 6. Script Maestro de Sincronización

En lugar de múltiples cron entries, usa un solo script. Está disponible en [`scripts/sync-all.sh`](scripts/sync-all.sh):

```bash
#!/bin/bash
# /opt/spotdl/sync-all.sh
# Script maestro de sincronización de playlists

LOG_DIR="/var/log/spotdl"
SYNC_DIR="/opt/spotdl"
MUSIC_DIR="/mnt/music/Playlists"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== Inicio sincronización: $DATE ==="

declare -A PLAYLISTS=(
  ["Top50-Global"]="37i9dQZEVXbMDoHDwVN2tF"
  ["Top50-USA"]="37i9dQZEVXbLRQDuF5jeBp"
  ["Top50-Spain"]="37i9dQZEVXbNFJfN1Vw8d9"
  ["Top50-Mexico"]="37i9dQZEVXbO3qyFxbkOE1"
  ["Top50-Argentina"]="37i9dQZEVXbMMy2roB9myp"
  ["Top50-Colombia"]="37i9dQZEVXbOa2lmxNORXQ"
)

for NAME in "${!PLAYLISTS[@]}"; do
  PLAYLIST_ID="${PLAYLISTS[$NAME]}"
  SYNC_FILE="$SYNC_DIR/$NAME.sync.spotdl"
  OUTPUT_DIR="$MUSIC_DIR/$NAME"
  URL="https://open.spotify.com/playlist/$PLAYLIST_ID"

  echo "--- Sincronizando: $NAME ---"

  if [ ! -f "$SYNC_FILE" ]; then
    echo "  Creando sync inicial para $NAME..."
    spotdl sync "$URL" \
      --save-file "$SYNC_FILE" \
      --output "$OUTPUT_DIR/{title}.{output-ext}"
  else
    echo "  Actualizando $NAME..."
    spotdl sync "$SYNC_FILE"
  fi

  # Pausa entre playlists para evitar throttling
  sleep 120
done

echo "=== Sincronización completada ==="
```

```bash
# Instalar y configurar
chmod +x /opt/spotdl/sync-all.sh

# Cron simplificado (una sola entrada)
crontab -e
# Agregar:
0 3 * * * /opt/spotdl/sync-all.sh >> /var/log/spotdl/sync.log 2>&1
```

> [!CAUTION]
> spotDL descarga audio de YouTube, no de Spotify directamente. Asegúrate de respetar las leyes de copyright de tu país. Este sistema está pensado para **uso personal**.

-----

### 7. Acceso Remoto con Tailscale

[Tailscale](https://tailscale.com/) crea una VPN mesh para acceder desde cualquier lugar sin abrir puertos.

```bash
# Instalar
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# HTTPS automático
tailscale serve https / http://localhost:4533
tailscale serve status
# → https://navidrome.tu-tailnet.ts.net
```

1. Instala Tailscale en tu teléfono (App Store / Play Store)
1. Inicia sesión con la misma cuenta
1. Accede a `http://100.x.y.z:4533` o tu URL `.ts.net`

-----

## 🎯 URLs Oficiales de Playlists Top 50

Playlists oficiales de Spotify, actualizadas diariamente. Usa directamente con spotDL:

|País            |Playlist ID             |URL                                                              |
|:---------------|:-----------------------|:----------------------------------------------------------------|
|🌍 Global        |`37i9dQZEVXbMDoHDwVN2tF`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF)|
|🇺🇸 Estados Unidos|`37i9dQZEVXbLRQDuF5jeBp`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbLRQDuF5jeBp)|
|🇪🇸 España        |`37i9dQZEVXbNFJfN1Vw8d9`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbNFJfN1Vw8d9)|
|🇲🇽 México        |`37i9dQZEVXbO3qyFxbkOE1`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbO3qyFxbkOE1)|
|🇦🇷 Argentina     |`37i9dQZEVXbMMy2roB9myp`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbMMy2roB9myp)|
|🇨🇴 Colombia      |`37i9dQZEVXbOa2lmxNORXQ`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbOa2lmxNORXQ)|
|🇬🇧 Reino Unido   |`37i9dQZEVXbLnolsZ8PSNw`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbLnolsZ8PSNw)|
|🇫🇷 Francia       |`37i9dQZEVXbIPWwFssbupI`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbIPWwFssbupI)|
|🇩🇪 Alemania      |`37i9dQZEVXbJiZcmkrIHGU`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbJiZcmkrIHGU)|
|🇧🇷 Brasil        |`37i9dQZEVXbMXbN3EUUhlg`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbMXbN3EUUhlg)|
|🇮🇹 Italia        |`37i9dQZEVXbIQnj7RRhdSX`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbIQnj7RRhdSX)|
|🇨🇱 Chile         |`37i9dQZEVXbL0GavIqMTeb`|[Abrir](https://open.spotify.com/playlist/37i9dQZEVXbL0GavIqMTeb)|


> Para agregar un nuevo país al script, simplemente añade una entrada al array `PLAYLISTS` en `sync-all.sh`.

-----

## 📱 Clientes Compatibles

Navidrome soporta la API Subsonic → compatible con **40+ aplicaciones**.

### Móvil

|App                                                                              |Plataforma   |Precio          |Notas                                    |
|:--------------------------------------------------------------------------------|:------------|:---------------|:----------------------------------------|
|**[Symfonium](https://symfonium.app/)**                                          |Android      |~$5 (único)     |⭐ La mejor para Android. CarPlay, offline|
|**[play:Sub](https://apps.apple.com/app/play-sub/id955329386)**                  |iOS          |Gratis / Premium|Excelente para iPhone                    |
|**[Amperfy](https://github.com/BLeeEZ/amperfy)**                                 |iOS          |Gratis          |Open source, muy completa                |
|**[Substreamer](https://substreamerapp.com/)**                                   |Android / iOS|Gratis / Premium|Multiplataforma                          |
|**[DSub](https://play.google.com/store/apps/details?id=github.daneren2005.dsub)**|Android      |Gratis          |Clásica, fiable                          |
|**[Tempo](https://apps.apple.com/app/tempo-music-videos/id6446932437)**          |iOS          |Gratis          |Interfaz moderna                         |

### Escritorio

|App                                              |Plataforma       |Notas                                   |
|:------------------------------------------------|:----------------|:---------------------------------------|
|**Interfaz Web**                                 |Navegador        |Incluida en Navidrome, sin instalar nada|
|**[Feishin](https://github.com/jeffvli/feishin)**|Win / Mac / Linux|Interfaz tipo Spotify                   |
|**[Sublime Music](https://sublimemusic.app/)**   |Linux            |GTK nativo, ligero                      |

### Datos de conexión

```
Servidor:    http://IP:4533  (o URL de Tailscale)
Usuario:     tu usuario de Navidrome
Contraseña:  tu contraseña de Navidrome
```

-----

## 🔧 Mantenimiento

### Actualizar Navidrome

```bash
cd /opt/navidrome
docker compose pull
docker compose up -d
```

### Backup

```bash
# Config y base de datos
tar -czf ~/backup-navidrome-$(date +%Y%m%d).tar.gz /opt/navidrome/data/

# Archivos de sincronización
tar -czf ~/backup-spotdl-$(date +%Y%m%d).tar.gz /opt/spotdl/
```

### Monitorear espacio

```bash
# Espacio por playlist
du -sh /mnt/music/Playlists/*

# Espacio total
df -h /mnt/music
```

> Cada playlist Top 50 ≈ **200-400 MB**. Con 6 países ≈ **1.5-2.5 GB** renovándose semanalmente.

### Limpieza automática de logs

```cron
# Agregar a crontab: borrar logs de más de 30 días
0 0 * * 0 find /var/log/spotdl/ -name '*.log' -mtime +30 -delete
```

-----

## ❓ Solución de Problemas

|Problema                |Solución                                                             |
|:-----------------------|:--------------------------------------------------------------------|
|Música nueva no aparece |Espera 15 min (escaneo) o fuerza desde **Ajustes → Escanear**        |
|spotDL error 403        |YouTube limita tu IP. Espera unas horas o usa `--audio youtube-music`|
|Docker no arranca en LXC|Verifica nesting: `pct set 200 --features nesting=1`                 |
|Permisos incorrectos    |`chown -R 1000:1000 /mnt/music` o ajusta `user` en compose           |
|Sin carátulas           |spotDL las incluye. Navidrome también busca online                   |
|Sin transcodificación   |Instala ffmpeg: `apt install ffmpeg`                                 |
|Cliente no conecta      |Verifica puerto 4533. Con Tailscale: misma tailnet                   |
|Canciones equivocadas   |Usa `--only-verified-results` para mayor precisión                   |

### Comandos de diagnóstico

```bash
# Logs de Navidrome en tiempo real
docker compose -f /opt/navidrome/docker-compose.yml logs -f

# Estado del contenedor
docker ps

# Probar spotDL
spotdl download "nombre de cancion" --output /tmp/test/

# Último log de sincronización
tail -50 /var/log/spotdl/sync.log
```

-----

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Si tienes mejoras, correcciones o nuevas ideas:

1. Haz un **Fork** del repositorio
1. Crea tu rama (`git checkout -b feature/mi-mejora`)
1. Commit (`git commit -m 'Agrega mi mejora'`)
1. Push (`git push origin feature/mi-mejora`)
1. Abre un **Pull Request**

### Ideas para contribuir

- [ ] Agregar más playlists por país
- [ ] Script de instalación automatizado (one-liner)
- [ ] Integración con Lidarr para gestión avanzada de música
- [ ] Docker Compose unificado (Navidrome + spotDL en un solo stack)
- [ ] Guía para Raspberry Pi
- [ ] Dashboard de monitoreo con Grafana

-----

## 📄 Licencia

Este proyecto está bajo la licencia [MIT](LICENSE). Siéntete libre de usarlo, modificarlo y distribuirlo.

-----

<div align="center">

**⭐ Si esta guía te fue útil, dale una estrella al repo ⭐**

Hecho con ☕ por [ServerHeaven](https://github.com/ServerHeaven)

<br>

[![GitHub](https://img.shields.io/badge/GitHub-ServerHeaven-181717?style=for-the-badge&logo=github)](https://github.com/ServerHeaven)
[![Repo](https://img.shields.io/badge/Repo-guia--spotify--lolcal--proxmox-1DB954?style=for-the-badge&logo=spotify)](https://github.com/ServerHeaven/guia-spotify-lolcal-proxmox)

</div>
