#!/system/bin/sh
# schedutil_balance: switch to schedutil (dynamic frequency) with balanced
# max-frequency caps, unlock lower bounds to hardware minimum.
LOG=/data/local/tmp/schedutil_balance.log
log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
echo "=== start ===" >> "$LOG"

i=0
while [ $i -lt 10 ]; do
  [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] && break
  sleep 1
  i=$((i+1))
done

CAP_LITTLE=1600000
CAP_BIG=1900000
CAP_PRIME=2000000

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

set_cpu 0 "$CAP_LITTLE"
set_cpu 1 "$CAP_LITTLE"
set_cpu 2 "$CAP_LITTLE"
set_cpu 3 "$CAP_LITTLE"
set_cpu 4 "$CAP_BIG"
set_cpu 5 "$CAP_BIG"
set_cpu 6 "$CAP_BIG"
set_cpu 7 "$CAP_PRIME"

if [ -w /sys/module/msm_performance/parameters/cpu_min_freq ]; then
  echo "0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0" > /sys/module/msm_performance/parameters/cpu_min_freq 2>/dev/null
fi
if [ -w /sys/module/msm_performance/parameters/cpu_max_freq ]; then
  echo "0:0 1:0 2:0 3:0 4:0 5:0 6:0 7:0" > /sys/module/msm_performance/parameters/cpu_max_freq 2>/dev/null
fi

log "done"
