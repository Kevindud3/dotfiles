#!/bin/sh

# Define the file that stores the count
COUNT_FILE="/tmp/script_run_count.txt"
RUN_LIMIT=9 # The number of times to run before executing the other script
TARGET_SCRIPT="./.config/mpdq/mpdq.sh"  # The path to the script to run after reaching the limit

# Initialize the count if the file doesn't exist
if [ ! -f "$COUNT_FILE" ]; then
	echo 0 > "$COUNT_FILE"
fi

# Read the current count from the file
COUNT=$(cat "$COUNT_FILE")

# Increment the count
COUNT=$((COUNT + 1))

# Save the updated count back to the file
echo "$COUNT" > "$COUNT_FILE"

# Check if the count has reached the limit
if [ "$COUNT" -ge "$RUN_LIMIT" ]; then
	# Reset the count
	echo 0 > "$COUNT_FILE"

		mpc consume on

  # Run the target script
  if [ -x "$TARGET_SCRIPT" ]; then
	  "$TARGET_SCRIPT"
  else
	  echo "Error: Target script not found or not executable."
  fi
fi
