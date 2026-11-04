#!/system/bin/sh
# schedutil_balance v1.1: apply after boot completes (late_start service),
# then keep a guard loop that restores the frequency caps if the vendor
# perf stack resets them.
LOG=/data/local/tmp/schedutil_balance.log
log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }

CAP_LITTLE=1600000
CAP_BIG=1900000
CAP_PRIME=2000000

# wait for boot completed (vendor services may still adjust freq afterwards)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 150 ]; do
  sleep 2
  i=$((i+1))
done
log "=== v1.1 start (boot waited ${i}x2s) ==="

set_cpu() {
  _cpu="$1"; _cap="$2"
  _d="/sys/devices/system/cpu/cpu${_cpu}/cpufreq"
  [ -e "$_d/scaling_governor" ] || return 0
  if [ -e "$_d/cpuinfo_min_freq" ]; then
    cat "$_d/cpuinfo_min_freq" > "$_d/scaling_min_freq" 2>/dev/null
  fi
  _hwmax=$(cat "$_d/cpuinfo_max_freq" 2>/dev/null)
  if [ -n "$_hwmax" ] && [ "$_cap" -gt "$_hwmax" ]; then
    _cap="$_hwmax"
  fi
  echo "$_cap" > "$_d/scaling_max_freq" 2>/dev/null
  echo schedutil > "$_d/scaling_governor" 2>/dev/null
  log "cpu${_cpu} gov=$(cat "$_d/scaling_governor" 2>/dev/null) min=$(cat "$_d/scaling_min_freq" 2>/dev/null) max=$(cat "$_d/scaling_max_freq" 2>/dev/null)"
}

apply_all() {
  set_cpu 0 "$CAP_LITTLE"
  set_cpu 1 "$CAP_LITTLE"
  set_cpu 2 "$CAP_LITTLE"
  set_cpu 3 "$CAP_LITTLE"
  set_cpu 4 "$CAP_BIG"
  set_cpu 5 "$CAP_BIG"
  set_cpu 6 "$CAP_BIG"
  set_cpu 7 "$CAP_PRIME"
}

apply_all
log "applied"

# guard loop: restore caps if vendor resets them (every 10s)
(
  while true; do
    sleep 10
    for kv in "0:$CAP_LITTLE" "1:$CAP_LITTLE" "2:$CAP_LITTLE" "3:$CAP_LITTLE" \
              "4:$CAP_BIG" "5:$CAP_BIG" "6:$CAP_BIG" "7:$CAP_PRIME"; do
      _c=${kv%%:*}
      _cap=${kv##*:}
      _d="/sys/devices/system/cpu/cpu${_c}/cpufreq"
      [ -e "$_d/scaling_max_freq" ] || continue
      _cur=$(cat "$_d/scaling_max_freq" 2>/dev/null)
      if [ -n "$_cur" ] && [ "$_cur" -gt "$_cap" ]; then
        echo "$_cap" > "$_d/scaling_max_freq" 2>/dev/null
        log "guard: cpu${_c} max restored ${_cur} -> ${_cap}"
      fi
      _gov=$(cat "$_d/scaling_governor" 2>/dev/null)
      if [ -n "$_gov" ] && [ "$_gov" != "schedutil" ]; then
        echo schedutil > "$_d/scaling_governor" 2>/dev/null
        log "guard: cpu${_c} governor restored ${_gov} -> schedutil"
      fi
    done
  done
) &
log "guard started"
