#!/bin/bash

echo "Crating hep.db database..."
sqlite3 hep.db 'drop table if exists p; create table p(omm nvarchar(20), datum date, vrijeme time, obis nvarchar(20), brojilo nvarchar(20), konstanta decimal, snaga decimal, energija decimal, status int);'
sqlite3 hep.db 'drop table if exists r; create table r(omm nvarchar(20), datum date, vrijeme time, obis nvarchar(20), brojilo nvarchar(20), konstanta decimal, snaga decimal, energija decimal, status int);'

echo "Importing all 'P' csv data into 'p' table..."
sqlite3 hep.db 'delete from p;'
cat *_p.csv | grep -v Mjerno | awk 'BEGIN {FS=OFS="\t"} {split($2, dateParts, "."); formattedDate = dateParts[3] "-" dateParts[2] "-" dateParts[1]; gsub(/,/, ".", $6); gsub(/,/, ".", $7); gsub(/,/, ".", $8); $2 = formattedDate; print}' | sed 's/\t/,/g' | sed 's/ ,/,/g' | sed 's/.$//' | sqlite3 -csv -separator ',' hep.db '.import /dev/stdin p'

echo "Importing all 'R' csv data into 'r' table..."
sqlite3 hep.db 'delete from r;'
cat *_r.csv | grep -v Mjerno | awk 'BEGIN {FS=OFS="\t"} {split($2, dateParts, "."); formattedDate = dateParts[3] "-" dateParts[2] "-" dateParts[1]; gsub(/,/, ".", $6); gsub(/,/, ".", $7); gsub(/,/, ".", $8); $2 = formattedDate; print}' | sed 's/\t/,/g' | sed 's/ ,/,/g' | sed 's/.$//' | sqlite3 -csv -separator ',' hep.db '.import /dev/stdin r'


source .config

echo
echo "Usage by month:"
sqlite3 -column -header hep.db "with x as (select datetime(p.datum, 'start of month') as mjesec, sum(p.energija) as P_kwh, sum(r.energija) as R_kwh from p join r on p.datum=r.datum and p.vrijeme = r.vrijeme where p.datum >= '${START_DAY}' group by 1 order by 1 asc) select *, (P_kwh-R_kwh) as razlika_kwh from x;"

echo
echo "Usage by year:"
sqlite3 -column -header hep.db "with data as (with x as (select datetime(p.datum, 'start of month') as mjesec, sum(p.energija) as P_kwh, sum(r.energija) as R_kwh from p join r on p.datum=r.datum and p.vrijeme = r.vrijeme where p.datum >= '${START_DAY}' group by 1 order by 1 asc) select *, (P_kwh-R_kwh) as razlika_kwh from x) select datetime(mjesec, 'start of year') as godina, sum(P_kwh), sum(R_kwh), sum(razlika_kwh) from data group by 1 order by 1 asc;"
