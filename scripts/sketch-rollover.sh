#!/bin/bash

IMPLEMENTATION_DIR=/home/p4ora/ddos-detection-sketches-p4
LOGS_DIR=logs

while true; do
    sleep 10
    python $IMPLEMENTATION_DIR/hyperloglog+countmin-sketch-controller.py --option switch_active_sketches >> $LOGS_DIR/rollover.txt
done
