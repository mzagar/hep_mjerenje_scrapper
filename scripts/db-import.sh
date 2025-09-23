#!/bin/bash

DB_PATH="data/database/hep.db"

echo "Creating hep.db database..."
sqlite3 "$DB_PATH" 'drop table if exists p; create table p(omm nvarchar(20), datum date, vrijeme time, obis nvarchar(20), brojilo nvarchar(20), konstanta decimal, snaga decimal, energija decimal, status int);'
sqlite3 "$DB_PATH" 'drop table if exists r; create table r(omm nvarchar(20), datum date, vrijeme time, obis nvarchar(20), brojilo nvarchar(20), konstanta decimal, snaga decimal, energija decimal, status int);'

echo "Importing all 'P' csv data into 'p' table..."
sqlite3 "$DB_PATH" 'delete from p;'
cd data/csv && cat *_p.csv | grep -v Mjerno | awk 'BEGIN {FS=OFS="\t"} {split($2, dateParts, "."); formattedDate = dateParts[3] "-" dateParts[2] "-" dateParts[1]; gsub(/,/, ".", $6); gsub(/,/, ".", $7); gsub(/,/, ".", $8); $2 = formattedDate; print}' | sed 's/\t/,/g' | sed 's/ ,/,/g' | sed 's/.$//' | sqlite3 -csv -separator ',' "../../$DB_PATH" '.import /dev/stdin p'

echo "Importing all 'R' csv data into 'r' table..."
sqlite3 "../../$DB_PATH" 'delete from r;'
cat *_r.csv | grep -v Mjerno | awk 'BEGIN {FS=OFS="\t"} {split($2, dateParts, "."); formattedDate = dateParts[3] "-" dateParts[2] "-" dateParts[1]; gsub(/,/, ".", $6); gsub(/,/, ".", $7); gsub(/,/, ".", $8); $2 = formattedDate; print}' | sed 's/\t/,/g' | sed 's/ ,/,/g' | sed 's/.$//' | sqlite3 -csv -separator ',' "../../$DB_PATH" '.import /dev/stdin r'

cd ../..

echo "Creating analytics database views..."
sqlite3 "$DB_PATH" < data/sql/fix_analytics_views.sql


