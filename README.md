# 'HEP mjerenje' data scraper

Scrapes data from HEP mjerenje site.

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
