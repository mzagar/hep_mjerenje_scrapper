#!/bin/bash

source .config

N_LAST_DAYS=30
echo "Usage in last $N_LAST_DAYS days:"
sqlite3 -column -header hep.db "\
  with data as (
    with x as (
      select datetime(p.datum, 'start of day') as dan, sum(p.energija) as P_kwh, sum(r.energija) as R_kwh 
      from p join r on p.datum=r.datum and p.vrijeme = r.vrijeme 
      where p.datum >= date(julianday(date('now'))-${N_LAST_DAYS}) and p.datum <= date('now') group by 1 order by 1 asc
    )  
    select *, (P_kwh-R_kwh) as razlika_kwh from x
  ) 
  select date(dan, 'start of day') as dan, sum(P_kwh) as P_kwh, sum(R_kwh) as R_kwh, sum(razlika_kwh) as razlika_kwh from data where P_kwh <> 0 or R_kwh <> 0 group by 1 order by 1 asc;"

echo
echo "Usage by month since ${START_DAY}:"
sqlite3 -column -header hep.db "\
  with x as (
    select datetime(p.datum, 'start of month') as mjesec, sum(p.energija) as P_kwh, sum(r.energija) as R_kwh 
    from p join r on p.datum=r.datum and p.vrijeme = r.vrijeme 
    where p.datum >= '${START_DAY}' 
    group by 1 order by 1 asc
  ) 
  select date(mjesec), P_kwh, R_kwh, (P_kwh-R_kwh) as razlika_kwh from x;"

echo
echo "Usage by year since ${START_DAY}:"
sqlite3 -column -header hep.db "\
  with data as (
    with x as (
      select datetime(p.datum, 'start of month') as mjesec, sum(p.energija) as P_kwh, sum(r.energija) as R_kwh 
      from p join r on p.datum=r.datum and p.vrijeme = r.vrijeme 
      where p.datum >= '${START_DAY}' group by 1 order by 1 asc
    ) 
    select *, (P_kwh-R_kwh) as razlika_kwh from x
  ) 
  select date(mjesec, 'start of year') as godina, sum(P_kwh) as P_kwh, sum(R_kwh) as R_kwh, sum(razlika_kwh) as razlika_kwh 
  from data 
  group by 1 order by 1 asc;"
