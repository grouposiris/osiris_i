#!/bin/bash

# Check if a target name is provided
if [ -z "$1" ]; then
  echo "Error: No target name provided."
  echo "Usage: ./generate_filelist.sh <target_name>"
  exit 1
fi

TARGET_NAME=$1
TARGET_DIR="../rtl/osiris_i"
OUTPUT_FILE="filelist.txt"

# Create or overwrite the filelist.txt file
> $OUTPUT_FILE

# Find all .v files in the target directory, excluding 'copy' and 'unused' files
# find $TARGET_DIR -type f -name "*.v" ! -name "*copy*.v" ! -path "*/unused/*" | sort >> $OUTPUT_FILE
find $TARGET_DIR -type f \( -name "*.v" -o -name "*.sv" \) ! -name "*copy*.v" ! -path "*/unused/*" | sort >> $OUTPUT_FILE


# Add the specific testbench based on the target name
echo "tb_$TARGET_NAME.sv" >> $OUTPUT_FILE

# Print a message to confirm that the filelist has been generated
echo "filelist.txt has been generated for $TARGET_NAME with the following Verilog files:"
cat $OUTPUT_FILE

echo ""
echo ""
