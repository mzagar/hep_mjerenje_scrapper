# HEP Energy Analytics Dashboard

Modern web-based analytics dashboard for Croatian HEP electricity meter data with comprehensive solar panel tracking, smart financial analysis, and interactive visualizations.

![Analytics Dashboard](https://img.shields.io/badge/Status-Production%20Ready-green) ![Python](https://img.shields.io/badge/Python-3.9+-blue) ![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

### 📊 **Interactive Analytics Dashboard**
- **Multi-tab interface** with Overview, Usage Patterns, Efficiency, Financial, and Comparison views
- **Real-time charts** with Plotly.js for responsive data visualization
- **Mobile-friendly design** that works on all devices
- **Smart period selection** with 13+ predefined ranges (last 7/30/90 days, this month, etc.)

### ⚡ **Smart Period Comparisons**
- **Intelligent comparison logic** - compares selected period vs equivalent previous period
- **Contextual labels** - "vs previous 30 days", "vs last quarter", "vs last year"
- **Dynamic metrics** - consumption, production, net energy, and self-consumption changes
- **Industry-standard behavior** like Google Analytics

### 💰 **Configurable Croatian HEP Tariff Calculator**
- **Single or dual tariff support** (jednokratna/dvotarifna)
- **Real-time tariff configuration** with EUR pricing (2024-2025 rates)
- **HEP netting formula** - authentic Croatian grid credit calculation (70-80% ratio)
- **Monthly fee inclusion** - complete cost modeling with distribution fees
- **Persistent settings** - saves your configuration automatically

### 🌞 **Solar Panel Analytics**
- **Production vs consumption tracking** with detailed breakdowns
- **Energy independence metrics** - daily, monthly, and yearly trends
- **Self-consumption optimization** - identify best usage patterns
- **Grid export analysis** - maximize solar investment returns

### 🔄 **Automated Data Pipeline**
- **Smart scraping** from HEP mjerenje portal (https://mjerenje.hep.hr/)
- **Incremental updates** - only fetches new data
- **Offline mode support** - test without live data
- **Robust error handling** with retry logic

### 📈 **Advanced Analytics**
- **Usage patterns** - hourly, daily, monthly consumption trends
- **Efficiency metrics** - energy independence and grid utilization
- **Financial projections** - monthly and yearly savings estimates
- **Time-of-use analysis** - peak vs off-peak optimization

## 🚀 Quick Start

### Prerequisites
- **Python 3.9+**
- **SQLite3** (included with Python)
- **Bash shell** (macOS/Linux/WSL)
- **HEP mjerenje account** with valid credentials

### Installation

1. **Clone and setup**
   ```bash
   git clone https://github.com/yourusername/hep_mjerenje_scrapper.git
   cd hep_mjerenje_scrapper
   make setup
   ```

2. **Configure HEP credentials**
   ```bash
   cp .config.template .config
   # Edit .config with your HEP username, password, and OIB
   ```

3. **Get data and start dashboard**
   ```bash
   make pipeline    # Scrape data from HEP
   make analytics   # Start dashboard at http://localhost:8080
   ```

### Alternative: Test without scraping
```bash
echo "HEP_OFFLINE=1" >> .config
make analytics
```

## 📁 Project Structure

```
hep_mjerenje_scrapper/
├── README.md                 # This file
├── Makefile                  # Build and run commands
├── .config.template          # Configuration template
├── .config                   # Your HEP credentials (created from template)
├── app/                      # Flask application
│   ├── app_analytics.py      # Main analytics dashboard
│   ├── app.py               # Legacy Flask app
│   ├── requirements.txt     # Python dependencies
│   └── templates/           # HTML templates
├── data/                    # Data storage
│   ├── csv/                # Raw CSV files from HEP
│   ├── database/           # SQLite database
│   └── sql/                # Analytics SQL views
├── scripts/                 # Data processing scripts
│   ├── get-hep-data.sh     # Main scraper
│   ├── db-import.sh        # Database import
│   ├── db-query.sh         # Query utilities
│   └── run_analytics.sh    # App launcher
└── grafana/                 # Alternative Grafana visualization
    ├── docker-compose.yaml  # Grafana Docker setup
    └── data/               # Grafana configuration
```

## ⚙️ Configuration

### HEP Credentials (.config file)
```bash
# Required - Your HEP mjerenje login
HEP_USERNAME="your_username"
HEP_PASSWORD="your_password"
HEP_OIB="your_oib_number"

# Optional - Leave as ALL for all meters
HEP_OMM="ALL"

# Optional - Prevent online scraping (for testing)
HEP_OFFLINE=1

# Data range settings
START_MONTH="03.2023"
START_DAY="01.03.2023"
```

### Financial Configuration
The dashboard includes a **live configuration panel** for Croatian HEP tariffs:

- **Tariff Type**: Single (jednokratna) or Dual (dvotarifna)
- **Pricing**: Current EUR rates (default: €0.11/kWh single, €0.13/€0.09 dual)
- **Feed-in Rate**: What HEP pays for excess solar (default: €0.07/kWh)
- **HEP Netting**: Realistic 75% credit ratio for returned energy
- **Monthly Fees**: Connection and distribution costs (default: €20/month)

## 🛠️ Usage

### Available Commands

**Setup & Configuration:**
```bash
make setup        # Complete setup (venv + install + config)
make config       # Create configuration file
```

**Data Pipeline:**
```bash
make scrape       # Scrape HEP data for all months
make import       # Import CSV data into SQLite
make query        # Run database queries
make pipeline     # Full pipeline (scrape + import + query)
```

**Applications:**
```bash
make analytics    # Start analytics dashboard (recommended)
make legacy       # Start legacy Flask app
make grafana      # Start Grafana visualization
```

**Maintenance:**
```bash
make clean        # Clean generated files
make reset        # Reset everything
make lint         # Check code quality
```

### Dashboard Features

#### **Overview Tab**
- Daily energy flow with production vs consumption
- Key performance metrics with smart period comparisons
- Monthly trends and net energy balance
- Quick insights into energy independence

#### **Usage Patterns Tab**
- Hourly consumption patterns (identify peak usage times)
- Daily patterns (weekday vs weekend differences)
- Monthly seasonal trends
- Time-of-use analysis (peak vs off-peak hours)

#### **Efficiency Tab**
- Energy independence trending (% of needs met by solar)
- Self-consumption optimization metrics
- Grid export percentage analysis
- Self-sufficiency tracking

#### **Financial Tab**
- **Configurable HEP tariff calculator**
- Real-time cost vs income analysis
- Solar savings breakdown with Croatian EUR pricing
- Monthly and yearly financial projections
- ROI analysis for solar installations

#### **Comparison Tab**
- Side-by-side period comparisons
- Quick presets (this vs last month, year-over-year, etc.)
- Comprehensive metrics comparison
- Trend analysis across different time periods

## 🔧 Advanced Usage

### Custom Date Ranges
The dashboard supports **13+ predefined periods**:
- Last 7/30/90/365 days
- This/last week, month, quarter, year
- Year-to-date, all-time, custom ranges

### API Endpoints
The Flask app provides REST API endpoints:
- `/api/overview` - Key metrics with smart comparisons
- `/api/daily` - Daily aggregated data
- `/api/patterns` - Usage patterns analysis
- `/api/efficiency` - Energy independence metrics
- `/api/financial` - Configurable cost analysis
- `/api/comparison` - Period comparison data

### Database Views
Optimized SQLite views for analytics:
- `daily_data` - Daily aggregations with efficiency metrics
- `monthly_data` - Monthly summaries with trends
- `efficiency_metrics` - Energy independence calculations
- `time_of_use_data` - Peak/off-peak analysis

## 🐳 Docker Support

### Grafana Alternative Visualization
```bash
make grafana    # Starts Grafana at http://localhost:3000
                # Username: admin, Password: admin
```

The Grafana setup provides an alternative data visualization approach with:
- Pre-configured SQLite datasource
- Custom dashboards for energy analysis
- Historical trend analysis
- Advanced charting capabilities

## 📊 Data Sources

### HEP Mjerenje Portal Integration
- Connects to official Croatian HEP electricity meter portal
- Downloads monthly CSV files for both directions (consumed/produced)
- Handles European CSV format (comma decimals, tab separation)
- Supports both single and three-phase meter configurations

### Data Processing
- Automatic date format conversion (DD.MM.YYYY → YYYY-MM-DD)
- Decimal format normalization (comma → dot for SQLite)
- Duplicate detection and handling
- Data validation and error correction

## 🛡️ Security & Privacy

- **Local processing** - all data stays on your machine
- **No cloud dependencies** - works completely offline
- **Secure credential storage** - .config file is git-ignored
- **Read-only HEP access** - only downloads your own meter data

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📋 Requirements

### System Requirements
- Python 3.9 or higher
- SQLite3 (included with Python)
- Bash shell (macOS/Linux/WSL on Windows)
- 100MB+ free disk space (for CSV data)

### Python Dependencies
See `app/requirements.txt`:
- Flask - Web framework
- pandas - Data analysis
- numpy - Numerical computing

### Optional Dependencies
- Docker & Docker Compose (for Grafana visualization)
- jq, curl, bc (for advanced shell scripting)

## 📈 Performance

- **Fast loading** - Optimized SQLite queries with indexes
- **Responsive charts** - Client-side rendering with Plotly.js
- **Minimal footprint** - Pure Python with no heavy dependencies
- **Smart caching** - Incremental data updates only

## 🐛 Troubleshooting

### Common Issues

**"No .config file found"**
```bash
cp .config.template .config
# Edit with your HEP credentials
```

**"Authentication failed"**
- Verify your HEP username/password in .config
- Check that your HEP account has meter access
- Try logging into https://mjerenje.hep.hr/ manually

**"No data available"**
```bash
make scrape      # Get data from HEP
make import      # Import into database
```

### Debug Mode
```bash
export HEP_DEBUG=1
make scrape      # Shows detailed scraping information
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Croatian HEP (Hrvatska elektroprivreda) for providing the mjerenje portal
- The open-source community for tools and libraries
- Solar energy enthusiasts for feedback and testing

---

**Made with ❤️ for the Croatian solar community**

For support, questions, or feature requests, please open an issue on GitHub.