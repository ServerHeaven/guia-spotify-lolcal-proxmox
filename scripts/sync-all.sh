#!/bin/bash
# Master playlist sync script / Script maestro de sincronización de playlists
# Usage / Uso: /opt/spotdl/sync-all.sh >> /var/log/spotdl/sync.log 2>&1
# NOTE: Spotify-owned playlists (e.g. the official "Top 50") return 404 in the
# Spotify Web API for apps without extended quota (since 2024-11-27). If a sync
# fails with 404, replace the IDs below with public user-made playlists.
# NOTA: las playlists propias de Spotify (p. ej. los «Top 50» oficiales) devuelven
# 404 en la Web API a apps sin cuota extendida (desde 27/11/2024). Si falla con
# 404, sustituye los IDs por playlists públicas de usuarios.

SYNC_DIR="/opt/spotdl"
MUSIC_DIR="/mnt/music/Playlists"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== Start sync / Inicio sincronización: $DATE ==="

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

  echo "--- Syncing / Sincronizando: $NAME ---"
  if [ ! -f "$SYNC_FILE" ]; then
    spotdl sync "$URL" \
      --save-file "$SYNC_FILE" \
      --output "$OUTPUT_DIR/{title}.{output-ext}"
  else
    spotdl sync "$SYNC_FILE"
  fi

  # Pause between playlists to avoid throttling / Pausa para evitar throttling
  sleep 120
done

echo "=== Sync finished / Sincronización completada ==="
