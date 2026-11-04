#!/system/bin/sh
# schedutil_balance v1.2: mode file + game auto-unlock + guard
LOG=/data/local/tmp/schedutil_balance.log
MODE_FILE=/data/local/tmp/schedutil_mode
MODDIR=${0%/*}
# game space / game center packages (auto-unlock while running)
GAME_PKGS="com.miui.gamebooster com.xiaomi.gamecenter com.miui.gamebooster.service"

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
: > "$LOG"
log "=== v1.2 start ==="

i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 150 ]; do
  sleep 2
  i=$((i+1))
done
log "boot completed (waited ${i}x2s)"

[ -f "$MODE_FILE" ] || echo balance > "$MODE_FILE"

game_running() {
  for _p in $GAME_PKGS; do
    if pidof "$_p" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

last_eff=""
while true; do
  mode=$(cat "$MODE_FILE" 2>/dev/null)
  case "$mode" in balance|normal) ;; *) mode=balance ;; esac
  if game_running; then eff=normal; else eff=$mode; fi
  if [ "$eff" != "$last_eff" ]; then
    log "apply: $eff (file=$mode, game=$(game_running && echo yes || echo no))"
    sh "$MODDIR/apply.sh" "$eff"
    last_eff="$eff"
  fi
  sleep 10
done
