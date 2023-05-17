#!/bin/bash

source .config

echo "month    from_grid(kWh) to_grid(kWh)   diff(kWh)"
for month in `bash ./month_sequence.sh ${START_MONTH}`; do bash ./get-hep.sh $month; done | awk '{print} {sum2 += $2; sum4 += $4; sum6 += $6} END {printf "Total : %.2f / %.2f / %.2f\n", sum2, sum4, sum6}'

