#!/bin/bash
# Usage: ./stress_and_monitor.sh <MIG_NAME> <ZONE> <MIN_INSTANCES> <STRESS_DURATION_in_seconds>
# Example: ./stress_and_monitor.sh my-mig us-central1-a 1 120

# Validate arguments
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <MIG_NAME> <ZONE> <MIN_INSTANCES> <STRESS_DURATION_in_seconds>"
  exit 1
fi

MIG_NAME=$1
ZONE=$2
MIN_INSTANCES=$3
STRESS_DURATION=$4

# Install stress tool if not installed
if ! command -v stress &> /dev/null; then
  echo "Installing 'stress' tool..."
  sudo apt-get update && sudo apt-get install -y stress
fi

# Determine number of CPU cores available
NUM_CORES=$(nproc)
echo "Detected $NUM_CORES CPU core(s)."

# Run stress test to simulate high CPU load
echo "Starting stress test for $STRESS_DURATION seconds..."
stress --cpu "$NUM_CORES" --timeout "$STRESS_DURATION"
echo "Stress test completed."

# Monitor the Managed Instance Group (MIG) for scale down
echo "Monitoring the instance group '$MIG_NAME' in zone '$ZONE' for scale down..."
# Define maximum wait time (in seconds) and polling interval
MAX_WAIT=600
WAIT_INTERVAL=30
TIME_ELAPSED=0

while true; do
  # Count current instances in the MIG
  CURRENT_COUNT=$(gcloud compute instance-groups managed list-instances "$MIG_NAME" --zone "$ZONE" --format="value(instance)" | wc -l)
  echo "Current number of instances: $CURRENT_COUNT"
  
  if [ "$CURRENT_COUNT" -le "$MIN_INSTANCES" ]; then
    echo "Instance group has scaled down to the baseline ($MIN_INSTANCES instance(s))."
    break
  fi

  if [ "$TIME_ELAPSED" -ge "$MAX_WAIT" ]; then
    echo "Timeout reached: Instance group did not scale down to baseline within $MAX_WAIT seconds."
    break
  fi

  sleep "$WAIT_INTERVAL"
  TIME_ELAPSED=$((TIME_ELAPSED + WAIT_INTERVAL))
done

echo "Script execution completed."
