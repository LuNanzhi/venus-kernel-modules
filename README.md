# venus-kernel-modules

小米 11（venus / SM8350）内核配套模块，FinaSU / Magisk 通用。

## schedutil_balance

把 CPU 调度切换到 **schedutil 动态调频**（替代 uperf 等固定频率方案），
在保持性能的前提下降低日常功耗。

| 项 | 内容 |
|---|---|
| governor | schedutil（按负载调频） |
| 小核 cpu0-3 | 上限 1.6 GHz，下限解锁到硬件最低 |
| 大核 cpu4-6 | 上限 1.9 GHz |
| 超大核 cpu7 | 上限 2.0 GHz |
| 其他 | 清除 msm_performance 频率锁定；解锁 min_freq |

### 安装

FinaSU 管理器 → 模块 → 从本地安装 → 选择 release 中的 zip → 重启。

### 验证

```sh
cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_governor   # schedutil
cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq   # 844800
cat /sys/devices/system/cpu/cpu7/cpufreq/scaling_max_freq   # 2000000
cat /data/local/tmp/schedutil_balance.log                   # 应用日志
```

### 回退

管理器里禁用/删除模块 → 重启，恢复内核默认（performance）。

### 注意

- 使用前请先移除 uperf 等锁定频率的模块（否则会被覆盖）
- 内核需支持 schedutil（本项目内核默认 performance，模块负责切换）
