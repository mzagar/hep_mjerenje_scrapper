# 'HEP mjerenje' data scraper

Scrapes consumed/produced electricity data from HEP mjerenje site: https://mjerenje.hep.hr/


## How to use

Define login parameters and from which month to start scraping data in .config file.

Run `bash ./run.sh` to run scrape.


## Configuration

Specify parameters in .config file (see .config.template).

Additionally, you can test without username/password with only `HEP_TOKEN` defined.


## How it works

When `run.sh` script runs it will, for each month starting with START_MONTH (month sequence is generated using script `month_sequence.sh`), execute `get-hep.sh` script which produces CSV data files.

If CSV file already exists, it will not be scraped again (only current month is scrapped everytime when script runs).


CSV data files are named as follows:

- `hep_<mm.yyyy>_p.csv` : 'P' HEP data (consumed from grid) 
- `hep_<mm.yyyy>_p.csv` : 'R' HEP data (returned to grid)

Script also calculates total consumed/produced/diff from start month.

## Example run

```
% bash ./run.sh
month    from_grid(kWh) to_grid(kWh)   diff(kWh)
03.2023: 187.50500000 / 285.64400000 / -98.13900000
04.2023: 385.00000000 / 328.08800000 / 56.91200000
05.2023: 195.46100000 / 145.62900000 / 49.83200000
Total : 767.97 / 759.36 / 8.61
```
## Importing data into sqlite

Run `bash db-import.sh` to create hep.db sqlite database and import all CSV data int 'p' and 'r' tables.

Example run:
```
% bash ./db-import.sh
Crating hep.db database...
Importing all 'P' csv data into 'p' table...
Importing all 'R' csv data into 'r' table...

Usage by month:
mjesec               P_kwh             R_kwh             razlika_kwh
-------------------  ----------------  ----------------  -----------------
2023-03-01 00:00:00  218.613           367.189999999999  -148.576999999999
2023-04-01 00:00:00  385.036999999998  328.088           56.948999999998
2023-05-01 00:00:00  195.51            145.629           49.8810000000002
2023-06-01 00:00:00  0                 0                 0
```
