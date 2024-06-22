#!/bin/bash

IMPLEMENTATION_DIR=/home/p4ora/ddos-detection-sketches-p4
LOGS_DIR=logs
PCAP_DIR=pcap
CARDINALITY=80000
NUM_HYPERLOGLOG_REGISTERS=256
PCAP_LOGS=false

# Remove old logs
sudo rm -rf $IMPLEMENTATION_DIR/scripts/$LOGS_DIR/*

# Start p4run
sleep 3

echo "Starting experiment with c = $CARDINALITY"

# Set custom CRCs
python $IMPLEMENTATION_DIR/hyperloglog+countmin-sketch-controller.py --option "set_hashes"
 
# Get estimates from switch continuously and write to log files
echo 'Start getting estimates from switch'
xterm -T "p4run" -e "python $IMPLEMENTATION_DIR/receive.py; exec bash" &
sleep 10

current_time=$(date +"%M %S")

# Send packets
echo "Starting to send packets"
mx h1 python $IMPLEMENTATION_DIR/scripts/send1.py --n-src $CARDINALITY
echo "Done sending packets"

# Kill process
sudo pkill -f "python /home/p4ora/ddos-detection-sketches-p4/receive.py"
sudo pkill -f "xterm"

python Chart.py $current_time
