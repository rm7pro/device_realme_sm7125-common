#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2020, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#	 * Redistributions of source code must retain the above copyright
#	   notice, this list of conditions and the following disclaimer.
#	 * Redistributions in binary form must reproduce the above copyright
#	   notice, this list of conditions and the following disclaimer in the
#	   documentation and/or other materials provided with the distribution.
#	 * Neither the name of The Linux Foundation nor
#	   the names of its contributors may be used to endorse or promote
#	   products derived from this software without specific prior written
#	   permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Changes from Qualcomm Innovation Center are provided under the following license:
# Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear
#

function configure_zram_parameters() { 
    swapoff /dev/block/zram0 2>/dev/null || true
    
    # Reset zram device
    [ -w /sys/block/zram0/reset ] && echo 1 > /sys/block/zram0/reset
    
    # Set compression algorithm (LZ4 optimized for ARM Cortex-A76/A55)
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || return 1
    
    # Optimize compression streams for 8-core big.LITTLE (2x A76 + 6x A55)
    echo 4 > /sys/block/zram0/max_comp_streams 2>/dev/null || true
    
    # Set 4GB zram size
    echo 4294967296 > /sys/block/zram0/disksize 2>/dev/null || return 1
    
    # Initialize and enable swap
    mkswap /dev/block/zram0 2>/dev/null || return 1
    swapon /dev/block/zram0 -p 32758 2>/dev/null || return 1
    
    # VM tuning - Optimized for Realme 6 Pro mobile workloads
    {
        # Swappiness: Slightly higher for 4GB zram to utilize it effectively
        echo 100 > /proc/sys/vm/swappiness
        
        # Cache pressure: Aggressive reclaim for mobile RAM management
        echo 100 > /proc/sys/vm/vfs_cache_pressure
        
        # Page-cluster: Small reads optimal for mobile flash + zram combo
        echo 1 > /proc/sys/vm/page-cluster
        
        # Dirty ratios: Conservative for mobile storage longevity
        echo 20 > /proc/sys/vm/dirty_ratio
        echo 5 > /proc/sys/vm/dirty_background_ratio
        
        # Extra free memory: Buffer for smooth operation
        echo 1024 > /proc/sys/vm/extra_free_kbytes
        
        # Memory overcommit: Conservative for stability
        echo 1 > /proc/sys/vm/overcommit_memory
        echo 50 > /proc/sys/vm/overcommit_ratio
        
        # Additional mobile optimizations for Snapdragon 720G
        echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
        echo 0 > /proc/sys/vm/oom_kill_allocating_task 2>/dev/null || true
        
        # Optimize readahead for mobile storage patterns
        echo 128 > /sys/block/*/queue/read_ahead_kb 2>/dev/null || true
        
    } 2>/dev/null
    
    return 0
}


# Core control parameters on silver
echo 0 0 0 0 1 1 > /sys/devices/system/cpu/cpu0/core_ctl/not_preferred
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres
echo 0 > /sys/devices/system/cpu/cpu6/core_ctl/enable

# Setting b.L scheduler parameters
# default sched up and down migrate values are 95 and 85
echo 65 > /proc/sys/kernel/sched_downmigrate
echo 71 > /proc/sys/kernel/sched_upmigrate
# default sched up and down migrate values are 100 and 95
echo 85 > /proc/sys/kernel/sched_group_downmigrate
echo 100 > /proc/sys/kernel/sched_group_upmigrate
echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

#colocation v3 settings
echo 740000 > /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz

# configure governor settings for little cluster
echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
echo 1248000 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

# configure governor settings for big cluster
echo "schedutil" > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
echo 0 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/up_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/down_rate_limit_us
echo 1267200 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_freq
echo 652800 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

# sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
echo 85 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_load

            echo "0:1248000" > /sys/module/cpu_boost/parameters/input_boost_freq
            echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms

            # Set Memory parameters
            configure_memory_parameters

            # Enable bus-dcvs
            for device in /sys/devices/platform/soc
            do
                for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
                do
                    echo "bw_hwmon" > $cpubw/governor
                    echo "2288 4577 7110 9155 12298 14236" > $cpubw/bw_hwmon/mbps_zones
                    echo 4 > $cpubw/bw_hwmon/sample_ms
                    echo 68 > $cpubw/bw_hwmon/io_percent
                    echo 20 > $cpubw/bw_hwmon/hist_memory
                    echo 0 > $cpubw/bw_hwmon/hyst_length
                    echo 80 > $cpubw/bw_hwmon/down_thres
                    echo 0 > $cpubw/bw_hwmon/guard_band_mbps
                    echo 250 > $cpubw/bw_hwmon/up_scale
                    echo 1600 > $cpubw/bw_hwmon/idle_mbps
                    echo 50 > $cpubw/polling_interval
                done

                for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
                do
                    echo "bw_hwmon" > $llccbw/governor
                    echo "1144 1720 2086 2929 3879 5931 6881" > $llccbw/bw_hwmon/mbps_zones
                    echo 4 > $llccbw/bw_hwmon/sample_ms
                    echo 68 > $llccbw/bw_hwmon/io_percent
                    echo 20 > $llccbw/bw_hwmon/hist_memory
                    echo 0 > $llccbw/bw_hwmon/hyst_length
                    echo 80 > $llccbw/bw_hwmon/down_thres
                    echo 0 > $llccbw/bw_hwmon/guard_band_mbps
                    echo 250 > $llccbw/bw_hwmon/up_scale
                    echo 1600 > $llccbw/bw_hwmon/idle_mbps
                    echo 40 > $llccbw/polling_interval
                done

                for npubw in $device/*npu-npu-ddr-bw/devfreq/*npu-npu-ddr-bw
                do
                    echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
                    echo "bw_hwmon" > $npubw/governor
                    echo "1144 1720 2086 2929 3879 5931 6881" > $npubw/bw_hwmon/mbps_zones
                    echo 4 > $npubw/bw_hwmon/sample_ms
                    echo 80 > $npubw/bw_hwmon/io_percent
                    echo 20 > $npubw/bw_hwmon/hist_memory
                    echo 10 > $npubw/bw_hwmon/hyst_length
                    echo 30 > $npubw/bw_hwmon/down_thres
                    echo 0 > $npubw/bw_hwmon/guard_band_mbps
                    echo 250 > $npubw/bw_hwmon/up_scale
                    echo 0 > $npubw/bw_hwmon/idle_mbps
                    echo 40 > $npubw/polling_interval
                    echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
                done
            done

            # memlat specific settings are moved to seperate file under
            # device/target specific folder
            setprop vendor.dcvs.prop 1

            # cpuset parameters
                echo 0-5 > /dev/cpuset/background/cpus
                echo 0-5 > /dev/cpuset/system-background/cpus

                # Turn off scheduler boost at the end
                echo 0 > /proc/sys/kernel/sched_boost

                # Turn on sleep modes.
                echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
          ;;
        esac

    ;;
esac


case "$target" in
    "lito")

    #Apply settings for lito
    if [ -f /sys/devices/soc0/soc_id ]; then
        soc_id=`cat /sys/devices/soc0/soc_id`
    fi

    case "$soc_id" in
        "400" | "440" )
        # Core control parameters on silver
        echo 0 0 0 0 1 1 > /sys/devices/system/cpu/cpu0/core_ctl/not_preferred
        echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
        echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
        echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
        echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres
        echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms

        # Disable Core control on gold, prime
        echo 0 > /sys/devices/system/cpu/cpu6/core_ctl/enable
        echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/enable

        # Setting b.L scheduler parameters
        echo 65 85 > /proc/sys/kernel/sched_downmigrate
        echo 71 95 > /proc/sys/kernel/sched_upmigrate
        echo 85 > /proc/sys/kernel/sched_group_downmigrate
        echo 100 > /proc/sys/kernel/sched_group_upmigrate
        echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks
        echo 0 > /proc/sys/kernel/sched_coloc_busy_hyst_ns
        echo 0 > /proc/sys/kernel/sched_coloc_busy_hysteresis_enable_cpus
        echo 0 > /proc/sys/kernel/sched_coloc_busy_hyst_max_ms

        # disable unfiltering
        echo 20000000 > /proc/sys/kernel/sched_task_unfilter_period
        echo 1 > /proc/sys/kernel/sched_task_unfilter_nr_windows

        # configure governor settings for silver cluster
        echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
        echo 1228800 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl
        echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
        echo 650000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/rtg_boost_freq

        # configure governor settings for gold cluster
        echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
        echo 0 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/down_rate_limit_us
        echo 1228800 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/hispeed_freq
        echo 85 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_load
        echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
        echo 0 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/pl
        echo 672000 > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
        echo 0 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/rtg_boost_freq

        # configure governor settings for gold+ cluster
        echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
        echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us
        echo 1228800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
        echo 85 > /sys/devices/system/cpu/cpu7/cpufreq/schedutil/hispeed_load
        echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
        echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl
        echo 672000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
        echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/rtg_boost_freq

        # colocation v3 settings
        echo 51 > /proc/sys/kernel/sched_min_task_util_for_boost
        echo 35 > /proc/sys/kernel/sched_min_task_util_for_colocation

        # Enable conservative pl
        echo 1 > /proc/sys/kernel/sched_conservative_pl

        echo "0:1228800" > /sys/devices/system/cpu/cpu_boost/input_boost_freq
        echo 120 > /sys/devices/system/cpu/cpu_boost/input_boost_ms

        # Set Memory parameters
        configure_memory_parameters

        if [ `cat /sys/devices/soc0/revision` == "2.0" ]; then
             # r2.0 related changes
             echo "0:1075200" > /sys/devices/system/cpu/cpu_boost/input_boost_freq
             echo 610000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/rtg_boost_freq
             echo 1075200 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
             echo 1152000 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/hispeed_freq
             echo 1401600 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
             echo 614400 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
             echo 652800 > /sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq
             echo 806400 > /sys/devices/system/cpu/cpufreq/policy7/scaling_min_freq
             echo 83 > /proc/sys/kernel/sched_asym_cap_sibling_freq_match_pct
        fi

        # Enable bus-dcvs
        for device in /sys/devices/platform/soc
        do
            for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
            do
                echo "bw_hwmon" > $cpubw/governor
                echo "2288 4577 7110 9155 12298 14236 16265" > $cpubw/bw_hwmon/mbps_zones
                echo 4 > $cpubw/bw_hwmon/sample_ms
                echo 68 > $cpubw/bw_hwmon/io_percent
                echo 20 > $cpubw/bw_hwmon/hist_memory
                echo 0 > $cpubw/bw_hwmon/hyst_length
                echo 80 > $cpubw/bw_hwmon/down_thres
                echo 0 > $cpubw/bw_hwmon/guard_band_mbps
                echo 250 > $cpubw/bw_hwmon/up_scale
                echo 1600 > $cpubw/bw_hwmon/idle_mbps
                echo 50 > $cpubw/polling_interval
            done

            for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
            do
                echo "bw_hwmon" > $llccbw/governor
                echo "1144 1720 2086 2929 3879 5931 6881 7980" > $llccbw/bw_hwmon/mbps_zones
                echo 4 > $llccbw/bw_hwmon/sample_ms
                echo 68 > $llccbw/bw_hwmon/io_percent
                echo 20 > $llccbw/bw_hwmon/hist_memory
                echo 0 > $llccbw/bw_hwmon/hyst_length
                echo 80 > $llccbw/bw_hwmon/down_thres
                echo 0 > $llccbw/bw_hwmon/guard_band_mbps
                echo 250 > $llccbw/bw_hwmon/up_scale
                echo 1600 > $llccbw/bw_hwmon/idle_mbps
                echo 50 > $llccbw/polling_interval
            done

            for npubw in $device/*npu*-ddr-bw/devfreq/*npu*-ddr-bw
            do
                echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
                echo "bw_hwmon" > $npubw/governor
                echo "1144 1720 2086 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
                echo 4 > $npubw/bw_hwmon/sample_ms
                echo 80 > $npubw/bw_hwmon/io_percent
                echo 20 > $npubw/bw_hwmon/hist_memory
                echo 10 > $npubw/bw_hwmon/hyst_length
                echo 30 > $npubw/bw_hwmon/down_thres
                echo 0 > $npubw/bw_hwmon/guard_band_mbps
                echo 250 > $npubw/bw_hwmon/up_scale
                echo 0 > $npubw/bw_hwmon/idle_mbps
                echo 40 > $npubw/polling_interval
                echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
            done

            for npullccbw in $device/*npu*-llcc-bw/devfreq/*npu*-llcc-bw
            do
                echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
                echo "bw_hwmon" > $npullccbw/governor
                echo "2288 4577 7110 9155 12298 14236 16265" > $npullccbw/bw_hwmon/mbps_zones
                echo 4 > $npullccbw/bw_hwmon/sample_ms
                echo 100 > $npullccbw/bw_hwmon/io_percent
                echo 20 > $npullccbw/bw_hwmon/hist_memory
                echo 10 > $npullccbw/bw_hwmon/hyst_length
                echo 30 > $npullccbw/bw_hwmon/down_thres
                echo 0 > $npullccbw/bw_hwmon/guard_band_mbps
                echo 250 > $npullccbw/bw_hwmon/up_scale
                echo 40 > $npullccbw/polling_interval
                echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
            done
        done
        # memlat specific settings are moved to seperate file under
        # device/target specific folder
        setprop vendor.dcvs.prop 0
        setprop vendor.dcvs.prop 1

        # cpuset parameters
        echo 0-5 > /dev/cpuset/background/cpus
        echo 0-5 > /dev/cpuset/system-background/cpus

        # Turn off scheduler boost at the end
        echo 0 > /proc/sys/kernel/sched_boost

        # Turn on sleep modes
        echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
        ;;
    esac

    #Apply settings for lagoon
    case "$soc_id" in
        "434" | "459" )

        # Core control parameters on silver
        echo 0 0 0 0 1 1 > /sys/devices/system/cpu/cpu0/core_ctl/not_preferred
        echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
        echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
        echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
        echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
        echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres

        # Disable Core control on gold
        echo 0 > /sys/devices/system/cpu/cpu6/core_ctl/enable


        # disable unfiltering
        echo 20000000 > /proc/sys/kernel/sched_task_unfilter_period

        # Setting b.L scheduler parameters
        # default sched up and down migrate values are 95 and 85
        echo 65 > /proc/sys/kernel/sched_downmigrate
        echo 71 > /proc/sys/kernel/sched_upmigrate

        # default sched up and down migrate values are 100 and 95
        echo 85 > /proc/sys/kernel/sched_group_downmigrate
        echo 100 > /proc/sys/kernel/sched_group_upmigrate
        echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks
        echo 0 > /proc/sys/kernel/sched_coloc_busy_hyst_ns
        echo 0 > /proc/sys/kernel/sched_coloc_busy_hysteresis_enable_cpus
        echo 0 > /proc/sys/kernel/sched_coloc_busy_hyst_max_ms

        # configure governor settings for little cluster
        echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
        echo 1248000 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
        echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

        # configure governor settings for big cluster
        echo "schedutil" > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
        echo 0 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/down_rate_limit_us
        echo 1248000 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_freq
        echo 652800 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

        #colocation v3 settings
        echo 740000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/rtg_boost_freq
        echo 0 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/rtg_boost_freq
        echo 51 > /proc/sys/kernel/sched_min_task_util_for_boost

        # sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
        echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
        echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
        echo 85 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_load

        # Enable conservative pl
        echo 1 > /proc/sys/kernel/sched_conservative_pl

        echo "0:1248000" > /sys/devices/system/cpu/cpu_boost/input_boost_freq
        echo 120 > /sys/devices/system/cpu/cpu_boost/input_boost_ms

        # Set Memory parameters
        configure_memory_parameters

        # Enable bus-dcvs
        for device in /sys/devices/platform/soc
        do
            for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
            do
                echo "bw_hwmon" > $cpubw/governor
                echo "2288 4577 7110 9155 12298 14236" > $cpubw/bw_hwmon/mbps_zones
                echo 4 > $cpubw/bw_hwmon/sample_ms
                echo 68 > $cpubw/bw_hwmon/io_percent
                echo 20 > $cpubw/bw_hwmon/hist_memory
                echo 0 > $cpubw/bw_hwmon/hyst_length
                echo 80 > $cpubw/bw_hwmon/down_thres
                echo 0 > $cpubw/bw_hwmon/guard_band_mbps
                echo 250 > $cpubw/bw_hwmon/up_scale
                echo 1600 > $cpubw/bw_hwmon/idle_mbps
                echo 50 > $cpubw/polling_interval
            done

            for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
            do
                echo "bw_hwmon" > $llccbw/governor
                echo "1144 1720 2086 2929 3879 5931 6881 8137" > $llccbw/bw_hwmon/mbps_zones
                echo 4 > $llccbw/bw_hwmon/sample_ms
                echo 68 > $llccbw/bw_hwmon/io_percent
                echo 20 > $llccbw/bw_hwmon/hist_memory
                echo 0 > $llccbw/bw_hwmon/hyst_length
                echo 80 > $llccbw/bw_hwmon/down_thres
                echo 0 > $llccbw/bw_hwmon/guard_band_mbps
                echo 250 > $llccbw/bw_hwmon/up_scale
                echo 1600 > $llccbw/bw_hwmon/idle_mbps
                echo 40 > $llccbw/polling_interval
            done

            for npubw in $device/*npu*-ddr-bw/devfreq/*npu*-ddr-bw
            do
                echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
                echo "bw_hwmon" > $npubw/governor
                echo "1144 1720 2086 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
                echo 4 > $npubw/bw_hwmon/sample_ms
                echo 80 > $npubw/bw_hwmon/io_percent
                echo 20 > $npubw/bw_hwmon/hist_memory
                echo 10 > $npubw/bw_hwmon/hyst_length
                echo 30 > $npubw/bw_hwmon/down_thres
                echo 0 > $npubw/bw_hwmon/guard_band_mbps
                echo 250 > $npubw/bw_hwmon/up_scale
                echo 0 > $npubw/bw_hwmon/idle_mbps
                echo 40 > $npubw/polling_interval
                echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
            done

            for npullccbw in $device/*npu*-llcc-bw/devfreq/*npu*-llcc-bw
            do
                echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
                echo "bw_hwmon" > $npullccbw/governor
                echo 40 > $npullccbw/polling_interval
                echo "2288 4577 7110 9155 12298 14236 16265" > $npullccbw/bw_hwmon/mbps_zones
                echo 4 > $npullccbw/bw_hwmon/sample_ms
                echo 100 > $npullccbw/bw_hwmon/io_percent
                echo 20 > $npullccbw/bw_hwmon/hist_memory
                echo 10 > $npullccbw/bw_hwmon/hyst_length
                echo 30 > $npullccbw/bw_hwmon/down_thres
                echo 0 > $npullccbw/bw_hwmon/guard_band_mbps
                echo 250 > $npullccbw/bw_hwmon/up_scale
                echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
            done
        done
        # memlat specific settings are moved to seperate file under
        # device/target specific folder
        setprop vendor.dcvs.prop 1

        # cpuset parameters
        echo 0-5 > /dev/cpuset/background/cpus
        echo 0-5 > /dev/cpuset/system-background/cpus

        # Turn off scheduler boost at the end
        echo 0 > /proc/sys/kernel/sched_boost

        # Turn off sleep modes
        echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
      ;;
    esac
esac

case "$target" in
    "bengal")

        if [ -f /sys/devices/soc0/soc_id ]; then
                soc_id=`cat /sys/devices/soc0/soc_id`
        else
                soc_id=`cat /sys/devices/system/soc/soc0/id`
        fi

        case "$soc_id" in
                 "417" | "420" | "444" | "445" )

            # Core control is temporarily disabled till bring up
            echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable
            echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
            # Core control parameters on big
            echo 40 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
            echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
            echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
            echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

            # Setting b.L scheduler parameters
            echo 67 > /proc/sys/kernel/sched_downmigrate
            echo 77 > /proc/sys/kernel/sched_upmigrate
            echo 85 > /proc/sys/kernel/sched_group_downmigrate
            echo 100 > /proc/sys/kernel/sched_group_upmigrate

            # cpuset settings
            echo 0-3 > /dev/cpuset/background/cpus
            echo 0-3 > /dev/cpuset/system-background/cpus


            # configure governor settings for little cluster
            echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
            echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
            echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
            echo 1305600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
            echo 614400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
            echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rtg_boost_freq

            # configure governor settings for big cluster
            echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
            echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/up_rate_limit_us
            echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/down_rate_limit_us
            echo 1401600 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_freq
            echo 1056000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
            echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/rtg_boost_freq

	    echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

            # sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
            echo -6 >  /sys/devices/system/cpu/cpu0/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu1/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu2/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu3/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu4/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu5/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
            echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
            echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_load
            echo 85 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_load

            # Set Memory parameters
            configure_memory_parameters

            # Enable bus-dcvs
            ddr_type=`od -An -tx /proc/device-tree/memory/ddr_device_type`
            ddr_type4="07"
            ddr_type3="05"

            for device in /sys/devices/platform/soc
            do
                for cpubw in $device/*cpu-cpu-ddr-bw/devfreq/*cpu-cpu-ddr-bw
                do
                    echo "bw_hwmon" > $cpubw/governor
                    echo 50 > $cpubw/polling_interval
                    echo 762 > $cpubw/min_freq
                    if [ ${ddr_type:4:2} == $ddr_type4 ]; then
                        # LPDDR4
                        echo "2288 3440 4173 5195 5859 7759 10322 11863 13763" > $cpubw/bw_hwmon/mbps_zones
                        echo 85 > $cpubw/bw_hwmon/io_percent
                    fi
                    if [ ${ddr_type:4:2} == $ddr_type3 ]; then
                        # LPDDR3
                        echo "1525 3440 5195 5859 7102" > $cpubw/bw_hwmon/mbps_zones
                        echo 34 > $cpubw/bw_hwmon/io_percent
                    fi
                    echo 4 > $cpubw/bw_hwmon/sample_ms
                    echo 90 > $cpubw/bw_hwmon/decay_rate
                    echo 190 > $cpubw/bw_hwmon/bw_step
                    echo 20 > $cpubw/bw_hwmon/hist_memory
                    echo 0 > $cpubw/bw_hwmon/hyst_length
                    echo 80 > $cpubw/bw_hwmon/down_thres
                    echo 0 > $cpubw/bw_hwmon/guard_band_mbps
                    echo 250 > $cpubw/bw_hwmon/up_scale
                   echo 1600 > $cpubw/bw_hwmon/idle_mbps
                done

            done
            # memlat specific settings are moved to seperate file under
            # device/target specific folder
            setprop vendor.dcvs.prop 1

            # colcoation v3 disabled
            echo 0 > /proc/sys/kernel/sched_min_task_util_for_boost
            echo 0 > /proc/sys/kernel/sched_min_task_util_for_colocation

            # Turn off scheduler boost at the end
            echo 0 > /proc/sys/kernel/sched_boost

            # Turn on sleep modes
            echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

            ;;
        esac

        # Scuba perf/power tunings
        case "$soc_id" in
             "441" )

            # Quad-core device. disable core_ctl
            echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable

            # Configure schedutil governor settings
            echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
            echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
            echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
            echo 1305600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
            echo 614400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
            echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rtg_boost_freq

            # sched_load_boost as -6 is equivalent to target load as 85.
            echo 0 > /proc/sys/kernel/sched_boost
            echo -6 > /sys/devices/system/cpu/cpu0/sched_load_boost
            echo -6 > /sys/devices/system/cpu/cpu1/sched_load_boost
            echo -6 > /sys/devices/system/cpu/cpu2/sched_load_boost
            echo -6 > /sys/devices/system/cpu/cpu3/sched_load_boost
            echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_load

            # Set Memory parameters
            configure_memory_parameters

            # Enable bus-dcvs
            ddr_type=`od -An -tx /proc/device-tree/memory/ddr_device_type`
            ddr_type4="07"
            ddr_type3="05"

            for device in /sys/devices/platform/soc
            do
                for cpubw in $device/*cpu-cpu-ddr-bw/devfreq/*cpu-cpu-ddr-bw
                do
                    echo "bw_hwmon" > $cpubw/governor
                    echo 50 > $cpubw/polling_interval
                    echo 762 > $cpubw/min_freq
                    if [ ${ddr_type:4:2} == $ddr_type4 ]; then
                        # LPDDR4
                        echo "2288 3440 4173 5195 5859 7759 10322 11863 13763" > $cpubw/bw_hwmon/mbps_zones
                        echo 85 > $cpubw/bw_hwmon/io_percent
                    fi
                    if [ ${ddr_type:4:2} == $ddr_type3 ]; then
                        # LPDDR3
                        echo "1525 3440 5195 5859 7102" > $cpubw/bw_hwmon/mbps_zones
                        echo 34 > $cpubw/bw_hwmon/io_percent
                    fi
                    echo 4 > $cpubw/bw_hwmon/sample_ms
                    echo 90 > $cpubw/bw_hwmon/decay_rate
                    echo 190 > $cpubw/bw_hwmon/bw_step
                    echo 20 > $cpubw/bw_hwmon/hist_memory
                    echo 0 > $cpubw/bw_hwmon/hyst_length
                    echo 80 > $cpubw/bw_hwmon/down_thres
                    echo 0 > $cpubw/bw_hwmon/guard_band_mbps
                    echo 250 > $cpubw/bw_hwmon/up_scale
                   echo 1600 > $cpubw/bw_hwmon/idle_mbps
                done

                for memlat in $device/*cpu*-lat/devfreq/*cpu*-lat
                do
                    echo "mem_latency" > $memlat/governor
                    echo 10 > $memlat/polling_interval
                    echo 400 > $memlat/mem_latency/ratio_ceil
                done

                for latfloor in $device/*cpu*-ddr-latfloor*/devfreq/*cpu-ddr-latfloor*
                do
                    echo "compute" > $latfloor/governor
                    echo 10 > $latfloor/polling_interval
                done
            done

            # Disable low power modes. Enable it after LPM stable
            echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
            ;;
        esac

    ;;
esac


#Apply settings for atoll
case "$target" in
    "atoll")

    # Core control parameters on silver
    echo 0 0 0 0 1 1 > /sys/devices/system/cpu/cpu0/core_ctl/not_preferred
    echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
    echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
    echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
    echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
    echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres
    echo 0 > /sys/devices/system/cpu/cpu6/core_ctl/enable

    # Setting b.L scheduler parameters
    # default sched up and down migrate values are 95 and 85
    echo 65 > /proc/sys/kernel/sched_downmigrate
    echo 71 > /proc/sys/kernel/sched_upmigrate
    # default sched up and down migrate values are 100 and 95
    echo 85 > /proc/sys/kernel/sched_group_downmigrate
    echo 100 > /proc/sys/kernel/sched_group_upmigrate
    echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

    #colocation v3 settings
    echo 740000 > /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz

    # configure governor settings for little cluster
    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 500 > /sys/devices/system/cpu/cpu0/cpufreq/performance/up_rate_limit_us
    echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/performance/down_rate_limit_us
    echo 1248000 > /sys/devices/system/cpu/cpu0/cpufreq/performance/hispeed_freq
    echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

    # configure governor settings for big cluster
    echo "performance" > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
    echo 500 > /sys/devices/system/cpu/cpu6/cpufreq/performance/up_rate_limit_us
    echo 20000 > /sys/devices/system/cpu/cpu6/cpufreq/performance/down_rate_limit_us
    echo 1267200 > /sys/devices/system/cpu/cpu6/cpufreq/performance/hispeed_freq
    echo 652800 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

    # sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
    echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
    echo 85 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_load

    #This modification is for power save
    # Enable conservative pl
    echo 1 > /proc/sys/kernel/sched_conservative_pl

    echo "0:1248000" > /sys/module/cpu_boost/parameters/input_boost_freq
    echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms

    # Set Memory parameters
    configure_memory_parameters

# Enable bus-dcvs
for device in /sys/devices/platform/soc
do
	for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
	do
		echo "bw_hwmon" > $cpubw/governor
		echo "2288 4577 7110 9155 12298 14236" > $cpubw/bw_hwmon/mbps_zones
		echo 4 > $cpubw/bw_hwmon/sample_ms
		echo 68 > $cpubw/bw_hwmon/io_percent
		echo 20 > $cpubw/bw_hwmon/hist_memory
		echo 0 > $cpubw/bw_hwmon/hyst_length
		echo 80 > $cpubw/bw_hwmon/down_thres
		echo 0 > $cpubw/bw_hwmon/guard_band_mbps
		echo 250 > $cpubw/bw_hwmon/up_scale
		echo 1600 > $cpubw/bw_hwmon/idle_mbps
		echo 50 > $cpubw/polling_interval
	done

	for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
	do
		echo "bw_hwmon" > $llccbw/governor
		echo "1144 1720 2086 2929 3879 5931 6881 8137" > $llccbw/bw_hwmon/mbps_zones
		echo 4 > $llccbw/bw_hwmon/sample_ms
		echo 68 > $llccbw/bw_hwmon/io_percent
		echo 20 > $llccbw/bw_hwmon/hist_memory
		echo 0 > $llccbw/bw_hwmon/hyst_length
		echo 80 > $llccbw/bw_hwmon/down_thres
		echo 0 > $llccbw/bw_hwmon/guard_band_mbps
		echo 250 > $llccbw/bw_hwmon/up_scale
		echo 1600 > $llccbw/bw_hwmon/idle_mbps
		echo 40 > $llccbw/polling_interval
	done

        for npubw in $device/*npu*-npu-ddr-bw/devfreq/*npu*-npu-ddr-bw
        do
            echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
            echo "bw_hwmon" > $npubw/governor
            echo "1144 1720 2086 2929 3879 5931 6881 8137" > $npubw/bw_hwmon/mbps_zones
            echo 4 > $npubw/bw_hwmon/sample_ms
            echo 80 > $npubw/bw_hwmon/io_percent
            echo 20 > $npubw/bw_hwmon/hist_memory
            echo 10 > $npubw/bw_hwmon/hyst_length
            echo 30 > $npubw/bw_hwmon/down_thres
            echo 0 > $npubw/bw_hwmon/guard_band_mbps
            echo 250 > $npubw/bw_hwmon/up_scale
            echo 0 > $npubw/bw_hwmon/idle_mbps
            echo 40 > $npubw/polling_interval
            echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
        done

    done

    # memlat specific settings are moved to seperate file under
    # device/target specific folder
    setprop vendor.dcvs.prop 1

    # cpuset parameters
    #This modification is for power save
    #echo 0-5 > /dev/cpuset/background/cpus
    echo 0-3 > /dev/cpuset/background/cpus
    echo 0-5 > /dev/cpuset/system-background/cpus

    # Turn off scheduler boost at the end
    echo 0 > /proc/sys/kernel/sched_boost

    # Turn on sleep modes
    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

    #/*Yongpeng Feng@BSP.kernel.Performance change IO scheduler to noop */
    echo noop > /sys/block/sda/queue/scheduler

    #/*Hu Yu@BSP.kernel.Performance create 1 kswapd thread for 7150*/
    echo 1 > /proc/sys/vm/kswapd_threads
  ;;
esac


case "$target" in
    "qcs605")

        #Apply settings for qcs605
        # Set the default IRQ affinity to the silver cluster. When a
        # CPU is isolated/hotplugged, the IRQ affinity is adjusted
        # to one of the CPU from the default IRQ affinity mask.
        echo 3f > /proc/irq/default_smp_affinity

        if [ -f /sys/devices/soc0/soc_id ]; then
                soc_id=`cat /sys/devices/soc0/soc_id`
        else
                soc_id=`cat /sys/devices/system/soc/soc0/id`
        fi

        if [ -f /sys/devices/soc0/hw_platform ]; then
            hw_platform=`cat /sys/devices/soc0/hw_platform`
        else
            hw_platform=`cat /sys/devices/system/soc/soc0/hw_platform`
        fi

        if [ -f /sys/devices/soc0/platform_subtype_id ]; then
            platform_subtype_id=`cat /sys/devices/soc0/platform_subtype_id`
        fi

        case "$soc_id" in
            "347" )

            # Start Host based Touch processing
            case "$hw_platform" in
              "Surf" | "RCM" | "QRD" )
                  start_hbtp
                  ;;
              "MTP" )
                  if [ $platform_subtype_id != 5 ]; then
                      start_hbtp
                  fi
                  ;;
            esac

      # Core control parameters on silver
      echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
      echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
      echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
      echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
      echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/is_big_cluster
      echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres

      # Setting b.L scheduler parameters
      echo 96 > /proc/sys/kernel/sched_upmigrate
      echo 90 > /proc/sys/kernel/sched_downmigrate
      echo 140 > /proc/sys/kernel/sched_group_upmigrate
      echo 120 > /proc/sys/kernel/sched_group_downmigrate

      # configure governor settings for little cluster
      echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
      echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rate_limit_us
      echo 1209600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
      echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

      # configure governor settings for big cluster
      echo "schedutil" > /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
      echo 0 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/rate_limit_us
      echo 1344000 > /sys/devices/system/cpu/cpu6/cpufreq/schedutil/hispeed_freq
      echo 825600 > /sys/devices/system/cpu/cpu6/cpufreq/scaling_min_freq

      echo "0:1209600" > /sys/module/cpu_boost/parameters/input_boost_freq
      echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms

      # Enable bus-dcvs
      for cpubw in /sys/class/devfreq/*qcom,cpubw*
            do
                echo "bw_hwmon" > $cpubw/governor
                echo 50 > $cpubw/polling_interval
                echo "1144 1720 2086 2929 3879 5931 6881" > $cpubw/bw_hwmon/mbps_zones
                echo 4 > $cpubw/bw_hwmon/sample_ms
                echo 68 > $cpubw/bw_hwmon/io_percent
                echo 20 > $cpubw/bw_hwmon/hist_memory
                echo 0 > $cpubw/bw_hwmon/hyst_length
                echo 80 > $cpubw/bw_hwmon/down_thres
                echo 0 > $cpubw/bw_hwmon/low_power_ceil_mbps
                echo 68 > $cpubw/bw_hwmon/low_power_io_percent
                echo 20 > $cpubw/bw_hwmon/low_power_delay
                echo 0 > $cpubw/bw_hwmon/guard_band_mbps
                echo 250 > $cpubw/bw_hwmon/up_scale
                echo 1600 > $cpubw/bw_hwmon/idle_mbps
            done

            #Enable mem_latency governor for DDR scaling
            for memlat in /sys/class/devfreq/*qcom,memlat-cpu*
            do
                echo "mem_latency" > $memlat/governor
                echo 10 > $memlat/polling_interval
                echo 400 > $memlat/mem_latency/ratio_ceil
            done

            #Enable mem_latency governor for L3 scaling
            for memlat in /sys/class/devfreq/*qcom,l3-cpu*
            do
                echo "mem_latency" > $memlat/governor
                echo 10 > $memlat/polling_interval
                echo 400 > $memlat/mem_latency/ratio_ceil
            done

            echo "cpufreq" > /sys/class/devfreq/soc:qcom,mincpubw/governor

            # cpuset parameters
            echo 0-5 > /dev/cpuset/background/cpus
            echo 0-5 > /dev/cpuset/system-background/cpus

            # Turn off scheduler boost at the end
            echo 0 > /proc/sys/kernel/sched_boost

            # Turn on sleep modes.
            echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
            echo 100 > /proc/sys/vm/swappiness
            ;;
        esac
    ;;
esac

case "$target" in
    "apq8084")
        echo 4 > /sys/module/lpm_levels/enable_low_power/l2
        echo 1 > /sys/module/msm_pm/modes/cpu0/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/retention/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/retention/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/retention/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/retention/idle_enabled
        echo 0 > /sys/module/msm_thermal/core_control/enabled
        echo 1 > /sys/devices/system/cpu/cpu1/online
        echo 1 > /sys/devices/system/cpu/cpu2/online
        echo 1 > /sys/devices/system/cpu/cpu3/online
        for devfreq_gov in /sys/class/devfreq/qcom,cpubw*/governor
        do
            echo "cpubw_hwmon" > $devfreq_gov
        done
        echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo "interactive" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
        echo "interactive" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
        echo "interactive" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
        echo "20000 1400000:40000 1700000:20000" > /sys/devices/system/cpu/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load
        echo 1497600 > /sys/devices/system/cpu/cpufreq/interactive/hispeed_freq
        echo "85 1500000:90 1800000:70" > /sys/devices/system/cpu/cpufreq/interactive/target_loads
        echo 40000 > /sys/devices/system/cpu/cpufreq/interactive/min_sample_time
        echo 20 > /sys/module/cpu_boost/parameters/boost_ms
        echo 1728000 > /sys/module/cpu_boost/parameters/sync_threshold
        echo 100000 > /sys/devices/system/cpu/cpufreq/interactive/sampling_down_factor
        echo 1497600 > /sys/module/cpu_boost/parameters/input_boost_freq
        echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms
        echo 1 > /dev/cpuctl/apps/cpu.notify_on_migrate
        echo 300000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        echo 300000 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
        echo 300000 > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
        echo 300000 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
        echo 1 > /sys/module/msm_thermal/core_control/enabled
        chown -h  system /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
        chown -h system /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        chown -h root.system /sys/devices/system/cpu/mfreq
        chmod -h 220 /sys/devices/system/cpu/mfreq
        chown -h root.system /sys/devices/system/cpu/cpu1/online
        chown -h root.system /sys/devices/system/cpu/cpu2/online
        chown -h root.system /sys/devices/system/cpu/cpu3/online
        chmod -h 664 /sys/devices/system/cpu/cpu1/online
        chmod -h 664 /sys/devices/system/cpu/cpu2/online
        chmod -h 664 /sys/devices/system/cpu/cpu3/online
    ;;
esac

case "$target" in
    "mpq8092")
        echo 4 > /sys/module/lpm_levels/enable_low_power/l2
        echo 1 > /sys/module/msm_pm/modes/cpu0/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/standalone_power_collapse/suspend_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/standalone_power_collapse/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu0/retention/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu1/retention/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu2/retention/idle_enabled
        echo 1 > /sys/module/msm_pm/modes/cpu3/retention/idle_enabled
        echo 0 > /sys/module/msm_thermal/core_control/enabled
        echo 1 > /sys/devices/system/cpu/cpu1/online
        echo 1 > /sys/devices/system/cpu/cpu2/online
        echo 1 > /sys/devices/system/cpu/cpu3/online
        echo "ondemand" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo "ondemand" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
        echo "ondemand" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
        echo "ondemand" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
        echo 50000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
        echo 90 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
        echo 1 > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy
        echo 300000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        echo 300000 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
        echo 300000 > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
        echo 300000 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
        echo 1 > /sys/module/msm_thermal/core_control/enabled
        chown -h  system /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
        chown -h system /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        chown -h root.system /sys/devices/system/cpu/mfreq
        chmod -h 220 /sys/devices/system/cpu/mfreq
        chown -h root.system /sys/devices/system/cpu/cpu1/online
        chown -h root.system /sys/devices/system/cpu/cpu2/online
        chown -h root.system /sys/devices/system/cpu/cpu3/online
        chmod -h 664 /sys/devices/system/cpu/cpu1/online
        chmod -h 664 /sys/devices/system/cpu/cpu2/online
        chmod -h 664 /sys/devices/system/cpu/cpu3/online
	;;
esac

case "$target" in
    "msm8992")
        # disable thermal bcl hotplug to switch governor
        echo 0 > /sys/module/msm_thermal/core_control/enabled
        echo -n disable > /sys/devices/soc.*/qcom,bcl.*/mode
        bcl_hotplug_mask=`cat /sys/devices/soc.*/qcom,bcl.*/hotplug_mask`
        echo 0 > /sys/devices/soc.*/qcom,bcl.*/hotplug_mask
        echo -n enable > /sys/devices/soc.*/qcom,bcl.*/mode
        echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
        # configure governor settings for little cluster
        echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_sched_load
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_migration_notif
        echo 19000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/go_hispeed_load
        echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/timer_rate
        echo 960000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/hispeed_freq
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy
        echo 80 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/target_loads
        echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/min_sample_time
        echo 80000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/max_freq_hysteresis
        echo 384000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        # online CPU4
        echo 1 > /sys/devices/system/cpu/cpu4/online
        # configure governor settings for big cluster
        echo "interactive" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
        echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_sched_load
        echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_migration_notif
        echo 19000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/go_hispeed_load
        echo 20000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/timer_rate
        echo 1536000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/hispeed_freq
        echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/io_is_busy
        echo 85 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/target_loads
        echo 40000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/min_sample_time
        echo 80000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/max_freq_hysteresis
        echo 384000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
        # re-enable thermal and BCL hotplug
        echo 1 > /sys/module/msm_thermal/core_control/enabled
        echo -n disable > /sys/devices/soc.*/qcom,bcl.*/mode
        echo $bcl_hotplug_mask > /sys/devices/soc.*/qcom,bcl.*/hotplug_mask
        echo $bcl_soc_hotplug_mask > /sys/devices/soc.*/qcom,bcl.*/hotplug_soc_mask
        echo -n enable > /sys/devices/soc.*/qcom,bcl.*/mode
        # plugin remaining A57s
        echo 1 > /sys/devices/system/cpu/cpu5/online
        # input boost configuration
        echo 0:1248000 > /sys/module/cpu_boost/parameters/input_boost_freq
        echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms
        # Enable task migration fixups in the scheduler
        echo 1 > /proc/sys/kernel/sched_migration_fixup
        for devfreq_gov in /sys/class/devfreq/qcom,cpubw*/governor
        do
            echo "bw_hwmon" > $devfreq_gov
        done
        #enable rps static configuration
        echo 8 >  /sys/class/net/rmnet_ipa0/queues/rx-0/rps_cpus
        echo 30 > /proc/sys/kernel/sched_small_task
    ;;
esac

case "$target" in
    "msm8994")
        # ensure at most one A57 is online when thermal hotplug is disabled
        echo 0 > /sys/devices/system/cpu/cpu5/online
        echo 0 > /sys/devices/system/cpu/cpu6/online
        echo 0 > /sys/devices/system/cpu/cpu7/online
        # in case CPU4 is online, limit its frequency
        echo 960000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
        # Limit A57 max freq from msm_perf module in case CPU 4 is offline
        echo "4:960000 5:960000 6:960000 7:960000" > /sys/module/msm_performance/parameters/cpu_max_freq
        # disable thermal bcl hotplug to switch governor
        echo 0 > /sys/module/msm_thermal/core_control/enabled
        for mode in /sys/devices/soc.0/qcom,bcl.*/mode
        do
            echo -n disable > $mode
        done
        for hotplug_mask in /sys/devices/soc.0/qcom,bcl.*/hotplug_mask
        do
            bcl_hotplug_mask=`cat $hotplug_mask`
            echo 0 > $hotplug_mask
        done
        for hotplug_soc_mask in /sys/devices/soc.0/qcom,bcl.*/hotplug_soc_mask
        do
            bcl_soc_hotplug_mask=`cat $hotplug_soc_mask`
            echo 0 > $hotplug_soc_mask
        done
        for mode in /sys/devices/soc.0/qcom,bcl.*/mode
        do
            echo -n enable > $mode
        done
        # configure governor settings for little cluster
        echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_sched_load
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_migration_notif
        echo 19000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/go_hispeed_load
        echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/timer_rate
        echo 960000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/hispeed_freq
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy
        echo 80 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/target_loads
        echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/min_sample_time
        echo 80000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/max_freq_hysteresis
        echo 384000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        # online CPU4
        echo 1 > /sys/devices/system/cpu/cpu4/online
        # Best effort limiting for first time boot if msm_performance module is absent
        echo 960000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
        # configure governor settings for big cluster
        echo "interactive" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
        echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_sched_load
        echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_migration_notif
        echo "19000 1400000:39000 1700000:19000" > /sys/devices/system/cpu/cpu4/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/go_hispeed_load
        echo 20000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/timer_rate
        echo 1248000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/hispeed_freq
        echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/io_is_busy
        echo "85 1500000:90 1800000:70" > /sys/devices/system/cpu/cpu4/cpufreq/interactive/target_loads
        echo 40000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/min_sample_time
        echo 80000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/max_freq_hysteresis
        echo 384000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
        # restore A57's max
        cat /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_max_freq > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
        # re-enable thermal and BCL hotplug
        echo 1 > /sys/module/msm_thermal/core_control/enabled
        for mode in /sys/devices/soc.0/qcom,bcl.*/mode
        do
            echo -n disable > $mode
        done
        for hotplug_mask in /sys/devices/soc.0/qcom,bcl.*/hotplug_mask
        do
            echo $bcl_hotplug_mask > $hotplug_mask
        done
        for hotplug_soc_mask in /sys/devices/soc.0/qcom,bcl.*/hotplug_soc_mask
        do
            echo $bcl_soc_hotplug_mask > $hotplug_soc_mask
        done
        for mode in /sys/devices/soc.0/qcom,bcl.*/mode
        do
            echo -n enable > $mode
        done
        # plugin remaining A57s
        echo 1 > /sys/devices/system/cpu/cpu5/online
        echo 1 > /sys/devices/system/cpu/cpu6/online
        echo 1 > /sys/devices/system/cpu/cpu7/online
        echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
        # Restore CPU 4 max freq from msm_performance
        echo "4:4294967295 5:4294967295 6:4294967295 7:4294967295" > /sys/module/msm_performance/parameters/cpu_max_freq
        # input boost configuration
        echo 0:1344000 > /sys/module/cpu_boost/parameters/input_boost_freq
        echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms
        # Setting b.L scheduler parameters
        echo 1 > /proc/sys/kernel/sched_migration_fixup
        echo 30 > /proc/sys/kernel/sched_small_task
        echo 20 > /proc/sys/kernel/sched_mostly_idle_load
        echo 3 > /proc/sys/kernel/sched_mostly_idle_nr_run
        echo 99 > /proc/sys/kernel/sched_upmigrate
        echo 85 > /proc/sys/kernel/sched_downmigrate
        echo 400000 > /proc/sys/kernel/sched_freq_inc_notify
        echo 400000 > /proc/sys/kernel/sched_freq_dec_notify
        #enable rps static configuration
        echo 8 >  /sys/class/net/rmnet_ipa0/queues/rx-0/rps_cpus
        for devfreq_gov in /sys/class/devfreq/qcom,cpubw*/governor
        do
            echo "bw_hwmon" > $devfreq_gov
        done
    ;;
esac

case "$target" in
    "msm8996")
        # disable thermal bcl hotplug to switch governor
        echo 0 > /sys/module/msm_thermal/core_control/enabled
        echo -n disable > /sys/devices/soc/soc:qcom,bcl/mode
        bcl_hotplug_mask=`cat /sys/devices/soc/soc:qcom,bcl/hotplug_mask`
        echo 0 > /sys/devices/soc/soc:qcom,bcl/hotplug_mask
        bcl_soc_hotplug_mask=`cat /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask`
        echo 0 > /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask
        echo -n enable > /sys/devices/soc/soc:qcom,bcl/mode
        # set sync wakee policy tunable
        echo 1 > /proc/sys/kernel/sched_prefer_sync_wakee_to_waker
        # configure governor settings for little cluster
        echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_sched_load
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_migration_notif
        echo 19000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/go_hispeed_load
        echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/timer_rate
        echo 960000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/hispeed_freq
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy
        echo 80 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/target_loads
        echo 19000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/min_sample_time
        echo 79000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/max_freq_hysteresis
        echo 300000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/ignore_hispeed_on_notif
        # online CPU2
        echo 1 > /sys/devices/system/cpu/cpu2/online
        # configure governor settings for big cluster
        echo "interactive" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
        echo 1 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/use_sched_load
        echo 1 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/use_migration_notif
        echo "19000 1400000:39000 1700000:19000 2100000:79000" > /sys/devices/system/cpu/cpu2/cpufreq/interactive/above_hispeed_delay
        echo 90 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/go_hispeed_load
        echo 20000 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/timer_rate
        echo 1248000 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/hispeed_freq
        echo 1 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/io_is_busy
        echo "85 1500000:90 1800000:70 2100000:95" > /sys/devices/system/cpu/cpu2/cpufreq/interactive/target_loads
        echo 19000 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/min_sample_time
        echo 79000 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/max_freq_hysteresis
        echo 300000 > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
        echo 1 > /sys/devices/system/cpu/cpu2/cpufreq/interactive/ignore_hispeed_on_notif
        # re-enable thermal and BCL hotplug
        echo 1 > /sys/module/msm_thermal/core_control/enabled
        echo -n disable > /sys/devices/soc/soc:qcom,bcl/mode
        echo $bcl_hotplug_mask > /sys/devices/soc/soc:qcom,bcl/hotplug_mask
        echo $bcl_soc_hotplug_mask > /sys/devices/soc/soc:qcom,bcl/hotplug_soc_mask
        echo -n enable > /sys/devices/soc/soc:qcom,bcl/mode
        # input boost configuration
        echo "0:1324800 2:1324800" > /sys/module/cpu_boost/parameters/input_boost_freq
        echo 40 > /sys/module/cpu_boost/parameters/input_boost_ms
        # Setting b.L scheduler parameters
        echo 0 > /proc/sys/kernel/sched_boost
        echo 1 > /proc/sys/kernel/sched_migration_fixup
        echo 45 > /proc/sys/kernel/sched_downmigrate
        echo 45 > /proc/sys/kernel/sched_upmigrate
        echo 400000 > /proc/sys/kernel/sched_freq_inc_notify
        echo 400000 > /proc/sys/kernel/sched_freq_dec_notify
        echo 3 > /proc/sys/kernel/sched_spill_nr_run
        echo 100 > /proc/sys/kernel/sched_init_task_load
        # Enable bus-dcvs
        for cpubw in /sys/class/devfreq/*qcom,cpubw*
        do
            echo "bw_hwmon" > $cpubw/governor
            echo 50 > $cpubw/polling_interval
            echo 1525 > $cpubw/min_freq
            echo "1525 5195 11863 13763" > $cpubw/bw_hwmon/mbps_zones
            echo 4 > $cpubw/bw_hwmon/sample_ms
            echo 34 > $cpubw/bw_hwmon/io_percent
            echo 20 > $cpubw/bw_hwmon/hist_memory
            echo 10 > $cpubw/bw_hwmon/hyst_length
            echo 0 > $cpubw/bw_hwmon/low_power_ceil_mbps
            echo 34 > $cpubw/bw_hwmon/low_power_io_percent
            echo 20 > $cpubw/bw_hwmon/low_power_delay
            echo 0 > $cpubw/bw_hwmon/guard_band_mbps
            echo 250 > $cpubw/bw_hwmon/up_scale
            echo 1600 > $cpubw/bw_hwmon/idle_mbps
        done

        for memlat in /sys/class/devfreq/*qcom,memlat-cpu*
        do
            echo "mem_latency" > $memlat/governor
            echo 10 > $memlat/polling_interval
        done
        echo "cpufreq" > /sys/class/devfreq/soc:qcom,mincpubw/governor

	soc_revision=`cat /sys/devices/soc0/revision`
	if [ "$soc_revision" == "2.0" ]; then
		#Disable suspend for v2.0
		echo pwr_dbg > /sys/power/wake_lock
	elif [ "$soc_revision" == "2.1" ]; then
		# Enable C4.D4.E4.M3 LPM modes
		# Disable D3 state
		echo 0 > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled
		echo 0 > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled
		# Disable DEF-FPC mode
		echo N > /sys/module/lpm_levels/system/pwr/cpu0/fpc-def/idle_enabled
		echo N > /sys/module/lpm_levels/system/pwr/cpu1/fpc-def/idle_enabled
		echo N > /sys/module/lpm_levels/system/perf/cpu2/fpc-def/idle_enabled
		echo N > /sys/module/lpm_levels/system/perf/cpu3/fpc-def/idle_enabled
	else
		# Enable all LPMs by default
		# This will enable C4, D4, D3, E4 and M3 LPMs
		echo N > /sys/module/lpm_levels/parameters/sleep_disabled
	fi
	echo N > /sys/module/lpm_levels/parameters/sleep_disabled
        # Starting io prefetcher service
        start iop

        # Set Memory parameters
        configure_memory_parameters
    ;;
esac

case "$target" in
    "sdm845")

        # Set the default IRQ affinity to the silver cluster. When a
        # CPU is isolated/hotplugged, the IRQ affinity is adjusted
        # to one of the CPU from the default IRQ affinity mask.
        echo f > /proc/irq/default_smp_affinity

        if [ -f /sys/devices/soc0/soc_id ]; then
                soc_id=`cat /sys/devices/soc0/soc_id`
        else
                soc_id=`cat /sys/devices/system/soc/soc0/id`
        fi

        if [ -f /sys/devices/soc0/hw_platform ]; then
                hw_platform=`cat /sys/devices/soc0/hw_platform`
        fi

        if [ -f /sys/devices/soc0/platform_subtype_id ]; then
                platform_subtype_id=`cat /sys/devices/soc0/platform_subtype_id`
        fi

        case "$soc_id" in
                "321" | "341")
                # Start Host based Touch processing
                case "$hw_platform" in
                    "QRD" )
                            case "$platform_subtype_id" in
                                   "32") #QVR845 do nothing
                                     ;;
                                   *)
                                         start_hbtp
                                     ;;
                            esac
                     ;;
                    *)
                          start_hbtp
                     ;;
                esac
         ;;
        esac
	# Core control parameters
	echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
	echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
	echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
	echo 1 > /sys/devices/system/cpu/cpu4/core_ctl/is_big_cluster
	echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

	# Setting b.L scheduler parameters
	echo 95 > /proc/sys/kernel/sched_upmigrate
	echo 85 > /proc/sys/kernel/sched_downmigrate
	echo 100 > /proc/sys/kernel/sched_group_upmigrate
	echo 95 > /proc/sys/kernel/sched_group_downmigrate
	echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

	# configure governor settings for little cluster
	echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rate_limit_us
	echo 1209600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
	echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/pl
        echo 576000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

	# configure governor settings for big cluster
	echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/rate_limit_us
	echo 1574400 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_freq
	echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/pl
	echo "0:1324800" > /sys/module/cpu_boost/parameters/input_boost_freq
	echo 120 > /sys/module/cpu_boost/parameters/input_boost_ms
	# Limit the min frequency to 825MHz
	echo 825000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq

        # Enable oom_reaper
        echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper

        # Enable bus-dcvs
        for cpubw in /sys/class/devfreq/*qcom,cpubw*
        do
            echo "bw_hwmon" > $cpubw/governor
            echo 50 > $cpubw/polling_interval
            echo "2288 4577 6500 8132 9155 10681" > $cpubw/bw_hwmon/mbps_zones
            echo 4 > $cpubw/bw_hwmon/sample_ms
            echo 50 > $cpubw/bw_hwmon/io_percent
            echo 20 > $cpubw/bw_hwmon/hist_memory
            echo 10 > $cpubw/bw_hwmon/hyst_length
            echo 0 > $cpubw/bw_hwmon/guard_band_mbps
            echo 250 > $cpubw/bw_hwmon/up_scale
            echo 1600 > $cpubw/bw_hwmon/idle_mbps
        done

        for llccbw in /sys/class/devfreq/*qcom,llccbw*
        do
            echo "bw_hwmon" > $llccbw/governor
            echo 50 > $llccbw/polling_interval
            echo "1720 2929 3879 5931 6881" > $llccbw/bw_hwmon/mbps_zones
            echo 4 > $llccbw/bw_hwmon/sample_ms
            echo 80 > $llccbw/bw_hwmon/io_percent
            echo 20 > $llccbw/bw_hwmon/hist_memory
            echo 10 > $llccbw/bw_hwmon/hyst_length
            echo 0 > $llccbw/bw_hwmon/guard_band_mbps
            echo 250 > $llccbw/bw_hwmon/up_scale
            echo 1600 > $llccbw/bw_hwmon/idle_mbps
        done

	#Enable mem_latency governor for DDR scaling
        for memlat in /sys/class/devfreq/*qcom,memlat-cpu*
        do
	echo "mem_latency" > $memlat/governor
            echo 10 > $memlat/polling_interval
            echo 400 > $memlat/mem_latency/ratio_ceil
        done

	#Enable mem_latency governor for L3 scaling
        for memlat in /sys/class/devfreq/*qcom,l3-cpu*
        do
            echo "mem_latency" > $memlat/governor
            echo 10 > $memlat/polling_interval
            echo 400 > $memlat/mem_latency/ratio_ceil
        done

        #Enable userspace governor for L3 cdsp nodes
        for l3cdsp in /sys/class/devfreq/*qcom,l3-cdsp*
        do
            echo "userspace" > $l3cdsp/governor
            chown -h system $l3cdsp/userspace/set_freq
        done

	#Gold L3 ratio ceil
        echo 4000 > /sys/class/devfreq/soc:qcom,l3-cpu4/mem_latency/ratio_ceil

	echo "compute" > /sys/class/devfreq/soc:qcom,mincpubw/governor
	echo 10 > /sys/class/devfreq/soc:qcom,mincpubw/polling_interval

	# cpuset parameters
        echo 0-3 > /dev/cpuset/background/cpus
        echo 0-3 > /dev/cpuset/system-background/cpus

	# Turn off scheduler boost at the end
        echo 0 > /proc/sys/kernel/sched_boost
	# Disable CPU Retention
        echo N > /sys/module/lpm_levels/L3/cpu0/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu1/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu2/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu3/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu4/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu5/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu6/ret/idle_enabled
        echo N > /sys/module/lpm_levels/L3/cpu7/ret/idle_enabled
	echo N > /sys/module/lpm_levels/L3/l3-dyn-ret/idle_enabled
        # Turn on sleep modes.
        echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
	echo 100 > /proc/sys/vm/swappiness
	echo 120 > /proc/sys/vm/watermark_scale_factor
    ;;
esac

case "$target" in
    "msmnile")
	# Core control parameters for gold
	echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
	echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
	echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
	echo 3 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

	# Core control parameters for gold+
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
	echo 60 > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
	echo 30 > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
	echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/task_thres
	# Controls how many more tasks should be eligible to run on gold CPUs
	# w.r.t number of gold CPUs available to trigger assist (max number of
	# tasks eligible to run on previous cluster minus number of CPUs in
	# the previous cluster).
	#
	# Setting to 1 by default which means there should be at least
	# 4 tasks eligible to run on gold cluster (tasks running on gold cores
	# plus misfit tasks on silver cores) to trigger assitance from gold+.
	echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/nr_prev_assist_thresh

	# Disable Core control on silver
	echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable

	# Setting b.L scheduler parameters
	echo 95 95 > /proc/sys/kernel/sched_upmigrate
	echo 85 85 > /proc/sys/kernel/sched_downmigrate
	echo 100 > /proc/sys/kernel/sched_group_upmigrate
#ifdef VENDOR_EDIT //SunFaliang@BSP.Power.Basic,Standardize the submission of Hypnus.
	echo 95 > /proc/sys/kernel/sched_group_downmigrate
#else
#	echo 10 > /proc/sys/kernel/sched_group_downmigrate
#endif
	echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

	# cpuset parameters
	echo 0-3 > /dev/cpuset/background/cpus
	echo 0-3 > /dev/cpuset/system-background/cpus

	# Turn off scheduler boost at the end
	echo 0 > /proc/sys/kernel/sched_boost

	# configure governor settings for silver cluster
	echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
	echo 1209600 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
	echo 300000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
	echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl

	# configure governor settings for gold cluster
	echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
	echo 1612800 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq
	echo 1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/pl

	# configure governor settings for gold+ cluster
	echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us
        echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
	echo 1612800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
	echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl

	# configure input boost settings
	echo "0:1324800" > /sys/module/cpu_boost/parameters/input_boost_freq
	echo 120 > /sys/module/cpu_boost/parameters/input_boost_ms

	# Disable wsf, beacause we are using efk.
	# wsf Range : 1..1000 So set to bare minimum value 1.
        echo 1 > /proc/sys/vm/watermark_scale_factor

        echo 0-3 > /dev/cpuset/background/cpus
        echo 0-3 > /dev/cpuset/system-background/cpus

        # Enable oom_reaper
	if [ -f /sys/module/lowmemorykiller/parameters/oom_reaper ]; then
		echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper
	else
		echo 1 > /proc/sys/vm/reap_mem_on_sigkill
	fi

	# Enable bus-dcvs
	for device in /sys/devices/platform/soc
	do
	    for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
	    do
		echo "bw_hwmon" > $cpubw/governor
		echo "2288 4577 7110 9155 12298 14236 15258" > $cpubw/bw_hwmon/mbps_zones
		echo 4 > $cpubw/bw_hwmon/sample_ms
		echo 50 > $cpubw/bw_hwmon/io_percent
		echo 20 > $cpubw/bw_hwmon/hist_memory
		echo 10 > $cpubw/bw_hwmon/hyst_length
		echo 30 > $cpubw/bw_hwmon/down_thres
		echo 0 > $cpubw/bw_hwmon/guard_band_mbps
		echo 250 > $cpubw/bw_hwmon/up_scale
		echo 1600 > $cpubw/bw_hwmon/idle_mbps
		echo 14236 > $cpubw/max_freq
                echo 40 > $cpubw/polling_interval
	    done

	    for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
	    do
		echo "bw_hwmon" > $llccbw/governor
		echo "1720 2929 3879 5931 6881 7980" > $llccbw/bw_hwmon/mbps_zones
		echo 4 > $llccbw/bw_hwmon/sample_ms
		echo 80 > $llccbw/bw_hwmon/io_percent
		echo 20 > $llccbw/bw_hwmon/hist_memory
		echo 10 > $llccbw/bw_hwmon/hyst_length
		echo 30 > $llccbw/bw_hwmon/down_thres
		echo 0 > $llccbw/bw_hwmon/guard_band_mbps
		echo 250 > $llccbw/bw_hwmon/up_scale
		echo 1600 > $llccbw/bw_hwmon/idle_mbps
		echo 6881 > $llccbw/max_freq
                echo 40 > $llccbw/polling_interval
	    done

	    for npubw in $device/*npu-npu-ddr-bw/devfreq/*npu-npu-ddr-bw
	    do
		echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
		echo "bw_hwmon" > $npubw/governor
		echo "1720 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
		echo 4 > $npubw/bw_hwmon/sample_ms
		echo 80 > $npubw/bw_hwmon/io_percent
		echo 20 > $npubw/bw_hwmon/hist_memory
		echo 6  > $npubw/bw_hwmon/hyst_length
		echo 30 > $npubw/bw_hwmon/down_thres
		echo 0 > $npubw/bw_hwmon/guard_band_mbps
		echo 250 > $npubw/bw_hwmon/up_scale
		echo 0 > $npubw/bw_hwmon/idle_mbps
                echo 40 > $npubw/polling_interval
		echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
	    done
	done

    # memlat specific settings are moved to seperate file under
    # device/target specific folder
    setprop vendor.dcvs.prop 1

    if [ -f /sys/devices/soc0/hw_platform ]; then
        hw_platform=`cat /sys/devices/soc0/hw_platform`
    else
        hw_platform=`cat /sys/devices/system/soc/soc0/hw_platform`
    fi

    if [ -f /sys/devices/soc0/platform_subtype_id ]; then
        platform_subtype_id=`cat /sys/devices/soc0/platform_subtype_id`
    fi

    case "$hw_platform" in
        "MTP" | "Surf" | "RCM" )
            # Start Host based Touch processing
            case "$platform_subtype_id" in
                "0" | "1" | "2" | "3" | "4")
                    start_hbtp
                    ;;
            esac
        ;;
        "HDK" )
            if [ -d /sys/kernel/hbtpsensor ] ; then
                start_hbtp
            fi
        ;;
    esac

    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
    configure_memory_parameters
    target_type=`getprop ro.hardware.type`
	if [ "$target_type" == "automotive" ]; then
           # update frequencies
           configure_automotive_sku_parameters
	fi

    ;;
esac

case "$target" in
    "sdmshrike")
	# Core control parameters for gold
	echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
	echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
	echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
	echo 3 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

	# Core control parameters for gold+
	echo 0 > /sys/devices/system/cpu/cpu7/core_ctl/min_cpus
	echo 60 > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
	echo 30 > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
	echo 100 > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
	echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/task_thres
	# Controls how many more tasks should be eligible to run on gold CPUs
	# w.r.t number of gold CPUs available to trigger assist (max number of
	# tasks eligible to run on previous cluster minus number of CPUs in
	# the previous cluster).
	#
	# Setting to 1 by default which means there should be at least
	# 4 tasks eligible to run on gold cluster (tasks running on gold cores
	# plus misfit tasks on silver cores) to trigger assitance from gold+.
	echo 1 > /sys/devices/system/cpu/cpu7/core_ctl/nr_prev_assist_thresh

	# Disable Core control on silver
	echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable

	# Setting b.L scheduler parameters
	echo 95 95 > /proc/sys/kernel/sched_upmigrate
	echo 85 85 > /proc/sys/kernel/sched_downmigrate
	echo 100 > /proc/sys/kernel/sched_group_upmigrate
	echo 10 > /proc/sys/kernel/sched_group_downmigrate
	echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

	# cpuset parameters
	echo 0-3 > /dev/cpuset/background/cpus
	echo 0-3 > /dev/cpuset/system-background/cpus

	# Turn off scheduler boost at the end
	echo 0 > /proc/sys/kernel/sched_boost

	# configure governor settings for silver cluster
	echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us
	echo 0 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
	echo 1209600 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq
	echo 576000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq
	echo 1 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/pl

	# configure governor settings for gold cluster
	echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy4/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/up_rate_limit_us
	echo 0 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/down_rate_limit_us
	echo 1612800 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq
	echo 1 > /sys/devices/system/cpu/cpufreq/policy4/schedutil/pl

	# configure governor settings for gold+ cluster
	echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy7/scaling_governor
	echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/up_rate_limit_us
	echo 0 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/down_rate_limit_us
	echo 1612800 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/hispeed_freq
	echo 1 > /sys/devices/system/cpu/cpufreq/policy7/schedutil/pl

	# configure input boost settings
	echo "0:1324800" > /sys/module/cpu_boost/parameters/input_boost_freq
	echo 120 > /sys/module/cpu_boost/parameters/input_boost_ms

	# Disable wsf, beacause we are using efk.
	# wsf Range : 1..1000 So set to bare minimum value 1.
        echo 1 > /proc/sys/vm/watermark_scale_factor

        echo 0-3 > /dev/cpuset/background/cpus
        echo 0-3 > /dev/cpuset/system-background/cpus

        # Enable oom_reaper
	if [ -f /sys/module/lowmemorykiller/parameters/oom_reaper ]; then
		echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper
	else
		echo 1 > /proc/sys/vm/reap_mem_on_sigkill
	fi

	# Enable bus-dcvs
	for device in /sys/devices/platform/soc
	do
	    for cpubw in $device/*cpu-cpu-llcc-bw/devfreq/*cpu-cpu-llcc-bw
	    do
		echo "bw_hwmon" > $cpubw/governor
		echo 40 > $cpubw/polling_interval
		echo "2288 4577 7110 9155 12298 14236 15258" > $cpubw/bw_hwmon/mbps_zones
		echo 4 > $cpubw/bw_hwmon/sample_ms
		echo 50 > $cpubw/bw_hwmon/io_percent
		echo 20 > $cpubw/bw_hwmon/hist_memory
		echo 10 > $cpubw/bw_hwmon/hyst_length
		echo 30 > $cpubw/bw_hwmon/down_thres
		echo 0 > $cpubw/bw_hwmon/guard_band_mbps
		echo 250 > $cpubw/bw_hwmon/up_scale
		echo 1600 > $cpubw/bw_hwmon/idle_mbps
		echo 14236 > $cpubw/max_freq
	    done

	    for llccbw in $device/*cpu-llcc-ddr-bw/devfreq/*cpu-llcc-ddr-bw
	    do
		echo "bw_hwmon" > $llccbw/governor
		echo 40 > $llccbw/polling_interval
		echo "1720 2929 3879 5931 6881 7980" > $llccbw/bw_hwmon/mbps_zones
		echo 4 > $llccbw/bw_hwmon/sample_ms
		echo 80 > $llccbw/bw_hwmon/io_percent
		echo 20 > $llccbw/bw_hwmon/hist_memory
		echo 10 > $llccbw/bw_hwmon/hyst_length
		echo 30 > $llccbw/bw_hwmon/down_thres
		echo 0 > $llccbw/bw_hwmon/guard_band_mbps
		echo 250 > $llccbw/bw_hwmon/up_scale
		echo 1600 > $llccbw/bw_hwmon/idle_mbps
		echo 6881 > $llccbw/max_freq
	    done

	    for npubw in $device/*npu-npu-ddr-bw/devfreq/*npu-npu-ddr-bw
	    do
		echo 1 > /sys/devices/virtual/npu/msm_npu/pwr
		echo "bw_hwmon" > $npubw/governor
		echo 40 > $npubw/polling_interval
		echo "1720 2929 3879 5931 6881 7980" > $npubw/bw_hwmon/mbps_zones
		echo 4 > $npubw/bw_hwmon/sample_ms
		echo 80 > $npubw/bw_hwmon/io_percent
		echo 20 > $npubw/bw_hwmon/hist_memory
		echo 6  > $npubw/bw_hwmon/hyst_length
		echo 30 > $npubw/bw_hwmon/down_thres
		echo 0 > $npubw/bw_hwmon/guard_band_mbps
		echo 250 > $npubw/bw_hwmon/up_scale
		echo 0 > $npubw/bw_hwmon/idle_mbps
		echo 0 > /sys/devices/virtual/npu/msm_npu/pwr
	done

	#Enable mem_latency governor for L3, LLCC, and DDR scaling
	for memlat in $device/*cpu*-lat/devfreq/*cpu*-lat
	do
		echo "mem_latency" > $memlat/governor
		echo 10 > $memlat/polling_interval
		echo 400 > $memlat/mem_latency/ratio_ceil
	done

	#Enable cdspl3 governor for L3 cdsp nodes
	for l3cdsp in $device/*cdsp-cdsp-l3-lat/devfreq/*cdsp-cdsp-l3-lat
	do
		echo "cdspl3" > $l3cdsp/governor
	done

	#Gold L3 ratio ceil
	echo 4000 > /sys/class/devfreq/soc:qcom,cpu6-cpu-l3-lat/mem_latency/ratio_ceil

	#Enable compute governor for gold latfloor
	for latfloor in $device/*cpu*-ddr-latfloor*/devfreq/*cpu-ddr-latfloor*
	do
		echo "compute" > $latfloor/governor
		echo 10 > $latfloor/polling_interval
	done

done

# cpuset parameters
echo 0-5 > /dev/cpuset/background/cpus
echo 0-5 > /dev/cpuset/system-background/cpus

# Turn off scheduler boost at the end
echo 0 > /proc/sys/kernel/sched_boost

# Turn on sleep modes
echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

# configure zram
configure_zram_parameters

# Post-setup services
case "$target" in
    "msm8660" | "msm8960" | "msm8226" | "msm8610" | "mpq8092" )
        start mpdecision
    ;;
    "msm8974")
        start mpdecision
        echo 512 > /sys/block/mmcblk0/bdi/read_ahead_kb
    ;;
    "msm8909" | "msm8916" | "msm8937" | "msm8952" | "msm8953" | "msm8994" | "msm8992" | "msm8996" | "msm8998" | "sdm660" | "apq8098_latv" | "sdm845" | "sdm710" | "msmnile" | "msmsteppe" | "sm6150" | "kona" | "lito" | "trinket" | "atoll" | "bengal" | "sdmshrike")
        setprop vendor.post_boot.parsed 1
    ;;
    "apq8084")
        rm /data/system/perfd/default_values
        start mpdecision
        echo 512 > /sys/block/mmcblk0/bdi/read_ahead_kb
        echo 512 > /sys/block/sda/bdi/read_ahead_kb
        echo 512 > /sys/block/sdb/bdi/read_ahead_kb
        echo 512 > /sys/block/sdc/bdi/read_ahead_kb
        echo 512 > /sys/block/sdd/bdi/read_ahead_kb
        echo 512 > /sys/block/sde/bdi/read_ahead_kb
        echo 512 > /sys/block/sdf/bdi/read_ahead_kb
        echo 512 > /sys/block/sdg/bdi/read_ahead_kb
        echo 512 > /sys/block/sdh/bdi/read_ahead_kb
    ;;
    "msm7627a")
        if [ -f /sys/devices/soc0/soc_id ]; then
            soc_id=`cat /sys/devices/soc0/soc_id`
        else
            soc_id=`cat /sys/devices/system/soc/soc0/id`
        fi
        case "$soc_id" in
            "127" | "128" | "129")
                start mpdecision
        ;;
        esac
    ;;
esac

# Enable Power modes and set the CPU Freq Sampling rates
case "$target" in
     "msm7627a")
        start qosmgrd
    echo 1 > /sys/module/pm2/modes/cpu0/standalone_power_collapse/idle_enabled
    echo 1 > /sys/module/pm2/modes/cpu1/standalone_power_collapse/idle_enabled
    echo 1 > /sys/module/pm2/modes/cpu0/standalone_power_collapse/suspend_enabled
    echo 1 > /sys/module/pm2/modes/cpu1/standalone_power_collapse/suspend_enabled
    #SuspendPC:
    echo 1 > /sys/module/pm2/modes/cpu0/power_collapse/suspend_enabled
    #IdlePC:
    echo 1 > /sys/module/pm2/modes/cpu0/power_collapse/idle_enabled
    echo 25000 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_rate
    ;;
esac

# Change adj level and min_free_kbytes setting for lowmemory killer to kick in
case "$target" in
     "msm7627a")
    echo 0,1,2,4,9,12 > /sys/module/lowmemorykiller/parameters/adj
    echo 5120 > /proc/sys/vm/min_free_kbytes
     ;;
esac

# Install AdrenoTest.apk if not already installed
if [ -f /data/prebuilt/AdrenoTest.apk ]; then
    if [ ! -d /data/data/com.qualcomm.adrenotest ]; then
        pm install /data/prebuilt/AdrenoTest.apk
    fi
fi

# Install SWE_Browser.apk if not already installed
if [ -f /data/prebuilt/SWE_AndroidBrowser.apk ]; then
    if [ ! -d /data/data/com.android.swe.browser ]; then
        pm install /data/prebuilt/SWE_AndroidBrowser.apk
    fi
fi

# Change adj level and min_free_kbytes setting for lowmemory killer to kick in
case "$target" in
     "msm8660")
        start qosmgrd
        echo 0,1,2,4,9,12 > /sys/module/lowmemorykiller/parameters/adj
        echo 5120 > /proc/sys/vm/min_free_kbytes
     ;;
esac
# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
    image_version="10:"
    image_version+=`getprop ro.build.id`
    image_version+=":"
    image_version+=`getprop ro.build.version.incremental`
    image_variant=`getprop ro.product.name`
    image_variant+="-"
    image_variant+=`getprop ro.build.type`
    oem_version=`getprop ro.build.version.codename`
    echo 10 > /sys/devices/soc0/select_image
    echo $image_version > /sys/devices/soc0/image_version
    echo $image_variant > /sys/devices/soc0/image_variant
    echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Change console log level as per console config property
console_config=`getprop persist.vendor.console.silent.config`
case "$console_config" in
    "1")
        echo "Enable console config to $console_config"
        echo 0 > /proc/sys/kernel/printk
        ;;
    *)
        echo "Enable console config to $console_config"
        ;;
esac

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path
