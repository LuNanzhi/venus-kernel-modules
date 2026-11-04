#!/system/bin/sh
# schedutil_balance v1.6: WebUI modes + driver lock + optional vendor stop + core lock
LOG=/data/local/tmp/schedutil_balance.log
MODE_FILE=/data/local/tmp/schedutil_mode
STOP_FILE=/data/local/tmp/schedutil_stop_services
LOCK_FILE=/data/local/tmp/schedutil_lock_cores
MODDIR=${0%/*}
log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
: > "$LOG"
log "=== v1.6 start ==="
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 150 ]; do sleep 2; i=$((i+1)); done
log "boot completed"
[ -f "$MODE_FILE" ] || echo balance > "$MODE_FILE"
[ -f "$STOP_FILE" ] || echo off > "$STOP_FILE"
[ -f "$LOCK_FILE" ] || echo on > "$LOCK_FILE"
CAP_LITTLE=1600000
CAP_BIG=1900000
CAP_PRIME=2000000
MP_BALANCE="0:$CAP_LITTLE 1:$CAP_LITTLE 2:$CAP_LITTLE 3:$CAP_LITTLE 4:$CAP_BIG 5:$CAP_BIG 6:$CAP_BIG 7:$CAP_PRIME"
stop_vendor_services() {
  for _svc in "vendor.qti.hardware.perf@2.2-service" "perfservice" "poweropt-service"; do
    _pids=$(pidof "$_svc" 2>/dev/null)
    for _p in $_pids; do kill -9 "$_p" 2>/dev/null && log "killed $_svc ($_p)"; done
  done
}
lock_cores() {
  for _c in 0 4 7; do
    _d="/sys/devices/system/cpu/cpu${_c}/core_ctl"
    [ -e "$_d/min_cpus" ] || continue
    _max=$(cat "$_d/max_cpus" 2>/dev/null)
    [ -n "$_max" ] && echo "$_max" > "$_d/min_cpus" 2>/dev/null
  done
}
last_eff=""
while true; do
  mode=$(cat "$MODE_FILE" 2>/dev/null); case "$mode" in balance|normal) ;; *) mode=balance ;; esac
  stop=$(cat "$STOP_FILE" 2>/dev/null); case "$stop" in on|off) ;; *) stop=off ;; esac
  lock=$(cat "$LOCK_FILE" 2>/dev/null); case "$lock" in on|off) ;; *) lock=on ;; esac
  if [ "$mode" != "$last_eff" ]; then
    log "apply: $mode"; sh "$MODDIR/apply.sh" "$mode"; last_eff="$mode"
  fi
  [ "$stop" = "on" ] && stop_vendor_services
  [ "$lock" = "on" ] && lock_cores
  if [ "$mode" = "balance" ]; then
    mp=$(cat /sys/module/msm_performance/parameters/cpu_max_freq 2>/dev/null | tr -d ' \n')
    want=$(echo "$MP_BALANCE" | tr -d ' \n')
    c0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    c4=$(cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq 2>/dev/null)
    c7=$(cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq 2>/dev/null)
    if [ "$mp" != "$want" ] || [ "$c0" -gt "$CAP_LITTLE" ] 2>/dev/null || [ "$c4" -gt "$CAP_BIG" ] 2>/dev/null || [ "$c7" -gt "$CAP_PRIME" ] 2>/dev/null; then
      log "guard: restore (cpu0=$c0 cpu4=$c4 cpu7=$c7)"; sh "$MODDIR/apply.sh" balance
    fi
  fi
  sleep 10
done
