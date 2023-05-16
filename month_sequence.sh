#!/bin/bash

# Get the specified starting month from the command line argument
start_month=$1

# Get the current month
current_month=$(date +"%m.%Y")

# Extract the month and year from the starting month
start_month_num=$(echo "$start_month" | cut -d '.' -f 1)
start_year=$(echo "$start_month" | cut -d '.' -f 2)

# Loop through the months from the starting month until the current month
while [[ "$start_month" != "$current_month" ]]; do
  # Print the current month
  printf "%s " "$start_month"

  # Increment the month
  if [[ "$start_month_num" -eq 12 ]]; then
    start_month_num=1
    start_year=$((start_year + 1))
  else
    start_month_num=$((start_month_num + 1))
  fi

  # Format the month with zero-padding if needed
  if [[ "$start_month_num" -lt 10 ]]; then
    start_month="0${start_month_num}.${start_year}"
  else
    start_month="${start_month_num}.${start_year}"
  fi
done

# Print the current month
printf "%s\n" "$current_month"

