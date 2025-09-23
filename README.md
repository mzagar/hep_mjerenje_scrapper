# HEP Energy Analytics Dashboard

Croatian HEP electricity meter data scraper with web-based analytics dashboard for solar panel tracking and energy analysis.

## Quick Start

```bash
git clone https://github.com/mzagar/hep_mjerenje_scrapper.git
cd hep_mjerenje_scrapper
make all
```

That's it! The command will:
1. Set up Python environment
2. Create `.config` file from template
3. Scrape your HEP data (if configured)
4. Start analytics dashboard at http://localhost:8080

## Configuration

Edit `.config` with your HEP credentials:

```bash
HEP_USERNAME='your@email.com'
HEP_PASSWORD='your_password'
HEP_OIB='your_oib_number'
HEP_OMM='ALL'

# Optional: Test without scraping
# HEP_OFFLINE=1

START_MONTH='03.2023'
START_DAY='2023-03-14'
```

## Project Structure

```
├── app/                    # Flask applications
│   ├── app_analytics.py   # Main analytics dashboard
│   └── templates/         # Web interface
├── data/                  # Data storage (gitignored)
│   ├── csv/              # Raw HEP CSV files
│   ├── database/         # SQLite database
│   └── sql/              # Database schemas
├── scripts/              # Data processing
│   ├── get-hep-data.sh   # HEP scraper
│   └── db-import.sh      # Database import
└── Makefile              # Automation
```

## How It Works

1. **Scrapes HEP mjerenje portal** - Downloads monthly CSV files for consumption (P) and production (R)
2. **Imports to SQLite** - Processes CSV data and creates analytics views
3. **Web dashboard** - 5-tab interface with charts and financial analysis

## Dashboard Features

- **Overview** - Daily energy flow, key metrics, period comparisons
- **Usage Patterns** - Hourly/daily/monthly consumption analysis
- **Efficiency** - Energy independence and self-consumption metrics
- **Financial** - Croatian HEP tariff calculator with EUR pricing
- **Compare** - Side-by-side period analysis

## Commands

```bash
make all        # Complete setup and start dashboard
make pipeline   # Update data only
make analytics  # Start dashboard only
make reset      # Reset (preserves .config)
make clean      # Clean generated files
```

## Example Output

When you run `make all`, you'll see:

```
🎯 Starting complete HEP Energy Analytics workflow...
📊 Step 1: Getting latest HEP data...
🚀 Scraping all months from 03.2023 to current...
📊 Importing data into SQLite database...
📈 Running database queries...
🚀 Step 2: Starting analytics dashboard...
📊 Dashboard will be available at: http://localhost:8080
```

## Requirements

- Python 3.9+
- SQLite3
- Bash shell
- HEP mjerenje account

## Security

- All data stays local (no cloud)
- Credentials in `.config` are gitignored
- Personal energy data protected from git commits

---

**Made for the Croatian solar community** 🇭🇷 ☀️