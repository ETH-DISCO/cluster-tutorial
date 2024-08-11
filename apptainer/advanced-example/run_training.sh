#!/bin/bash
CUDA_DEVICES=$(nvidia-smi --query-gpu=index --format=csv,noheader | tr '\n' ',' | sed 's/,$//')
NUM_DEVICES=$(echo \$CUDA_DEVICES | tr ',' '\n' | wc -l)

python3 /vesselformer/train.py \
    --config configs/synth_3D.yaml \
    --cuda_visible_device \$CUDA_DEVICES \
    --nproc_per_node \$NUM_DEVICES
