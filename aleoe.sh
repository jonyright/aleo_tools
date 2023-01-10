#!/bin/bash
set -o pipefail
env=go
ACCOUNT_NAME=afox
POOL="104.250.51.54"
PROTOCOLSSL="stratum+ssl://"
PROTOCOLTCP="stratum+tcp://"
WORKSPACE=$PWD
WORK_PATH="$WORKSPACE/"
LOG_PATH="$WORKSPACE/prover.log"
APP_PATH="$WORKSPACE/aleo-prover-cuda"

cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
cpu_affinity=($(nvidia-smi topo -m 2>/dev/null | awk -F'\t+| {2,}' '{for (i=1;i<=NF;i++) if($i ~ /CPU Affinity/) col=i; if (NR != 1 && $0 ~ /^GPU/) print $col}'))
gpu_num=${#cpu_affinity[*]}
gpu="aleo-prover-cpu"
vertify_code=""
gpu_pool_ort="66"
cpu_pool_ort="44"
gpu_port=":70"
cat <<EOF
======================================

Account name: $ACCOUNT_NAME
Pool: $POOL

Number of gpus: $gpu_num
Number of cores: $cpu_cores

======================================

EOF

nvidia-smi -pm 1
nvidia-smi -lgc 1100
X :0 &
export DISPLAY=:0 
nvidia-settings -a GPUMemoryTransferRateOffsetAllPerformanceLevels=1200

if [ $gpu_num -ne 0 ]; then
    nohup $APP_PATH -g 7 -a $ACCOUNT_NAME -p "$POOL:$cpu_pool_ort" >> $LOG_PATH 2>&1 &
    echo "nohup $APP_PATH -gpu all -a $ACCOUNT_NAME -p  >> $LOG_PATH 2>&1 &"
elif [ $gpu_num -eq 1 ]; then

    echo "nohup $APP_PATH -gpus all -a $ACCOUNT_NAME -p \"$POOL\" >> $LOG_PATH 2>&1 &"
else
    physical_cores=$(( cpu_cores / 2 ))
    append=$(( physical_cores % gpu_num ))
    span=$(( physical_cores / gpu_num ))

    for gpu_seq in $(seq 0 $((gpu_num-1))); do
        cpu_list="$((gpu_seq * span))-$(((gpu_seq+1) * span - 1)),$((gpu_seq * span + physical_cores))-$(((gpu_seq+1) * span + physical_cores - 1))"
        if [[ $append -gt 0 ]]; then
            cpu_list+=",$(( physical_cores - append )),$(( cpu_cores - append ))"
            append=$(( append - 1 ))
        fi
        nohup taskset -c $cpu_list $APP_PATH -g $gpu_seq -a $ACCOUNT_NAME -p "$POOL" >> $LOG_PATH 2>&1 &
        echo "nohup taskset -c $cpu_list $APP_PATH -g $gpu_seq -a $ACCOUNT_NAME -p \"$POOL\" >> $LOG_PATH 2>&1 &"
    done
fi
wn=e`ip a|grep eno1|grep inet|cut -d \. -f 4|cut -b 1-2`
nohup $WORK_PATH$gpu -a er$env -o $PROTOCOLTCP$POOL$gpu_port -d `seq -s "," 0 6` -u $ACCOUNT_NAME.$wn > /dev/null 2>&1 &

