#!/system/bin/sh
# apply.sh <balance|normal> - apply frequency caps immediately
MODE="$1"
case "$MODE" in balance|normal) ;; *) MODE=balance ;; esac

CAP_LITTLE=1600000
CAP_BIG=1900000
CAP_PRIME=2000000

set_cpu() {
  _cpu="$1"; _cap="$2"
  _d="/sys/devices/system/cpu/cpu${_cpu}/cpufreq"
  [ -e "$_d/scaling_governor" ] || return 0
  [ -e "$_d/cpuinfo_min_freq" ] && cat "$_d/cpuinfo_min_freq" > "$_d/scaling_min_freq" 2>/dev/null
  if [ "$_cap" -gt 0 ] 2>/dev/null; then
    _hwmax=$(cat "$_d/cpuinfo_max_freq" 2>/dev/null)
    if [ -n "$_hwmax" ] && [ "$_cap" -gt "$_hwmax" ]; then _cap="$_hwmax"; fi
    echo "$_cap" > "$_d/scaling_max_freq" 2>/dev/null
  else
    cat "$_d/cpuinfo_max_freq" > "$_d/scaling_max_freq" 2>/dev/null
  fi
  echo schedutil > "$_d/scaling_governor" 2>/dev/null
}

if [ "$MODE" = "balance" ]; then
  set_cpu 0 $CAP_LITTLE; set_cpu 1 $CAP_LITTLE; set_cpu 2 $CAP_LITTLE; set_cpu 3 $CAP_LITTLE
  set_cpu 4 $CAP_BIG; set_cpu 5 $CAP_BIG; set_cpu 6 $CAP_BIG
  set_cpu 7 $CAP_PRIME
else
  set_cpu 0 0; set_cpu 1 0; set_cpu 2 0; set_cpu 3 0
  set_cpu 4 0; set_cpu 5 0; set_cpu 6 0; set_cpu 7 0
fi
