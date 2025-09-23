# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a HEP (Croatian Electric Utility) electricity meter data scraper that collects consumption and production data from the HEP mjerenje portal (https://mjerenje.hep.hr/). The system consists of bash-based data scrapers, SQLite database storage, and a Flask web interface with Grafana visualization.

## Project Structure

```
├── app/                    # Flask web applications
│   ├── app.py             # Legacy Flask app
│   ├── app_analytics.py   # Advanced analytics dashboard
│   ├── requirements.txt   # Python dependencies
│   └── templates/         # HTML templates
├── data/                  # Data storage and schemas
│   ├── csv/              # CSV data files (gitignored)
│   ├── database/         # SQLite database (gitignored)
│   └── sql/              # Database schemas and views
├── scripts/              # Bash automation scripts
│   ├── get-hep-data.sh   # Core HEP data scraper
│   ├── db-import.sh      # Database import operations
│   ├── db-query.sh       # Database queries and reports
│   ├── run.sh            # Main orchestration script
│   ├── month_sequence.sh # Month sequence utility
│   └── run_analytics.sh  # Analytics app launcher
├── grafana/              # Grafana configuration (gitignored)
├── Makefile              # Build automation and workflow
├── .config.template      # Configuration template
└── .config               # User credentials (gitignored)
```

## Key Scripts and Architecture

### Data Collection Pipeline
1. **`scripts/run.sh`** - Main orchestration script that:
   - Runs `scripts/get-hep-data.sh` for each month from START_MONTH to current
   - Imports data using `scripts/db-import.sh`
   - Queries data using `scripts/db-query.sh`

2. **`scripts/get-hep-data.sh`** - Core scraper that:
   - Authenticates with HEP API using username/password or token
   - Downloads monthly CSV data for both directions (P=consumed, R=returned)
   - Handles offline mode via HEP_OFFLINE env var
   - Always refreshes current month data unless offline

3. **`scripts/month_sequence.sh`** - Utility to generate month sequence from start month to current

4. **`scripts/db-import.sh`** - Database operations:
   - Creates SQLite tables `p` (consumed) and `r` (returned)
   - Imports all CSV files with date format conversion
   - Handles European CSV format (comma decimals, tab separation)
   - Creates analytics database views from `data/sql/fix_analytics_views.sql`

5. **`scripts/db-query.sh`** - Reporting queries:
   - Last 30 days usage
   - Monthly aggregations since START_DAY
   - Yearly aggregations

### Configuration
- **`.config`** file (based on `.config.template`) contains:
  - HEP credentials: `HEP_USERNAME`, `HEP_PASSWORD`, `HEP_OIB`, `HEP_OMM`
  - Optional `HEP_TOKEN` for authentication
  - `HEP_OFFLINE=1` to prevent online scraping
  - `START_MONTH` and `START_DAY` for data range

### Web Interface
- **`app/app.py`** - Basic Flask application (legacy)
- **`app/app_analytics.py`** - Advanced analytics Flask application providing:
  - Comprehensive dashboard at `/` with multiple chart types
  - Rich API endpoints for analytics data:
    - `/api/overview` - Key metrics and totals
    - `/api/daily` - Daily aggregated data with filtering
    - `/api/hourly` - Hourly data analysis
    - `/api/monthly` - Monthly aggregations
    - `/api/patterns` - Usage patterns (hourly/daily/monthly averages)
    - `/api/time-of-use` - Peak vs off-peak analysis
    - `/api/efficiency` - Energy independence metrics
    - `/api/financial` - Cost analysis with Croatian tariffs
    - `/api/comparison` - Period comparison functionality
  - SQLite database views for optimized analytics queries

### Data Structure
- CSV files: `data/csv/hep_MM.YYYY_p.csv` (consumed) and `data/csv/hep_MM.YYYY_r.csv` (returned)
- SQLite database: `data/database/hep.db` with tables `p` and `r`
- Database views: Defined in `data/sql/fix_analytics_views.sql` for optimized analytics
- Each record contains: OMM, date, time, OBIS, meter number, constant, power, energy, status

## Development Commands

### Makefile Workflow (Recommended)
```bash
# Complete setup and start analytics dashboard
make all

# Individual targets
make setup          # Setup environment and config
make pipeline       # Run data pipeline (scrape + import + query)
make analytics      # Start analytics dashboard
make grafana        # Start Grafana with Docker
make clean          # Clean generated files
make reset          # Reset environment (preserves .config)
```

### Manual Script Execution
```bash
# Main data collection and processing
bash scripts/run.sh

# Scrape specific month
bash scripts/get-hep-data.sh 03.2023

# Import data only
bash scripts/db-import.sh

# Query data only
bash scripts/db-query.sh
```

### Web Interface
```bash
# Using Makefile (recommended)
make analytics

# Manual setup
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r app/requirements.txt

# Run advanced analytics dashboard (recommended)
cd app && python app_analytics.py
# OR use convenience script
bash scripts/run_analytics.sh

# Run legacy Flask app
cd app && python app.py

# Run with Docker Compose (includes Grafana)
cd grafana && docker-compose up
```

### Services
- Flask analytics app: http://localhost:8080
- Grafana dashboard: http://localhost:3000 (admin/admin)

## Analytics Features

The advanced analytics dashboard (`app/app_analytics.py`) provides:

### Dashboard Tabs
- **Overview**: Daily energy flow, monthly trends, net energy balance
- **Usage Patterns**: Hourly/daily/monthly averages, time-of-use analysis
- **Efficiency**: Energy independence trends, self-consumption metrics
- **Financial**: Cost analysis with Croatian tariffs, savings calculations
- **Compare**: Side-by-side period comparisons

### Key Metrics
- Energy independence percentage
- Self-consumption vs grid export ratios
- Peak vs off-peak consumption analysis
- Financial savings from solar production
- Month-over-month comparisons

### Interactive Features
- **Comprehensive date range selection** with 13+ predefined periods:
  - Last 7/30/90/365 days
  - This/last week, month, quarter, year
  - Year-to-date, all-time, custom ranges
  - **All metrics and charts update dynamically** based on selected range
- **Quick comparison presets** for common period comparisons:
  - This vs last month, this vs last year
  - Quarter comparisons, summer vs winter analysis
- **Interactive chart explanations** with info hover buttons:
  - Every chart has an "ℹ" button explaining what it shows
  - Plain-language explanations of complex energy concepts
  - Context-aware help for better understanding
- Real-time chart interactions with Plotly.js
- CSV/PDF export functionality
- Current period indicator in dashboard header
- Responsive design for mobile/desktop

### Database Views
The system creates optimized SQLite views for analytics:
- `hourly_data` - Hourly aggregations with power metrics
- `daily_data` - Daily totals with efficiency calculations
- `monthly_data` - Monthly summaries with trend analysis
- `usage_patterns` - Average patterns by time dimension
- `time_of_use_data` - Peak/off-peak breakdown
- `efficiency_metrics` - Energy independence calculations

## Dependencies
- **System**: curl, jq, bc, awk, sed, sqlite3, base64, make
- **Python**: flask, pandas, numpy (see app/requirements.txt)
- **Optional**: Docker and Docker Compose for containerized Grafana setup

## Security and Configuration
- **Credentials**: `.config` file contains HEP login credentials (gitignored)
- **Data Protection**: Personal energy data in `data/csv/` and `data/database/` are gitignored
- **Configuration Template**: Use `.config.template` as starting point
- **Reset Safety**: `make reset` preserves your `.config` file with credentials

## Data Flow
1. Authentication with HEP API
2. Download base64-encoded CSV data for P/R directions
3. Decode and store CSV files locally
4. Parse and import CSV data into SQLite with date/decimal format conversion
5. Generate usage reports and serve via web interface

## Configuration Notes
- `HEP_OMM='ALL'` is recommended for getting all meter data
- Current month files are always refreshed unless `HEP_OFFLINE=1`
- European date format (DD.MM.YYYY) is converted to ISO format (YYYY-MM-DD)
- Decimal commas are converted to dots for SQLite compatibility