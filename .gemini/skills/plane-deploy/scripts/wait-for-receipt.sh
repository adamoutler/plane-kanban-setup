#!/bin/bash
# wait-for-receipt.sh
RECEIPT="/tmp/jenkins-receipt-plane.log"
TIMEOUT=300

# Remove the old receipt to ensure we only get new feedback
rm -f "$RECEIPT"

echo "Waiting for deployment receipt at $RECEIPT (max ${TIMEOUT}s)..."

# Ensure file exists
touch "$RECEIPT"

# Use tail -F to handle file overwrites (Jenkins curl), and sed to print live until "Finished:"
timeout "$TIMEOUT" tail -n +1 -F "$RECEIPT" 2>/dev/null | sed '/Finished:/ q'