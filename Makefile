# HEP Energy Scraper Makefile
# Manages the lifecycle of the HEP electricity meter data scraper

.PHONY: help setup venv install config scrape import query analytics docker clean all

# Default target
help:
	@echo "HEP Energy Scraper - Available targets:"
	@echo ""
	@echo "  Setup & Configuration:"
	@echo "    setup       - Complete setup (venv + install + config)"
	@echo "    venv        - Create Python virtual environment"
	@echo "    install     - Install Python dependencies"
	@echo "    config      - Create configuration file from template"
	@echo ""
	@echo "  Data Pipeline:"
	@echo "    scrape      - Scrape HEP data for all months"
	@echo "    import      - Import CSV data into SQLite database"
	@echo "    query       - Run database queries and show reports"
	@echo "    pipeline    - Full data pipeline (scrape + import + query)"
	@echo ""
	@echo "  Applications:"
	@echo "    analytics   - Start analytics dashboard (recommended)"
	@echo "    legacy      - Start legacy Flask app"
	@echo "    grafana     - Start Grafana visualization with Docker"
	@echo ""
	@echo "  Maintenance:"
	@echo "    clean       - Clean up generated files"
	@echo "    reset       - Reset everything (clean + remove venv)"
	@echo ""
	@echo "  All-in-One:"
	@echo "    all         - Complete setup and start analytics dashboard"
	@echo ""

# Setup targets
setup: venv install config
	@echo "✅ Setup complete! Run 'make all' to start the application."

venv:
	@echo "🐍 Creating Python virtual environment..."
	python -m venv .venv
	@echo "✅ Virtual environment created at .venv/"

install: venv
	@echo "📦 Installing Python dependencies..."
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install -r app/requirements.txt
	@echo "✅ Dependencies installed"

config:
	@if [ ! -f .config ]; then \
		echo "⚙️  Creating configuration file..."; \
		cp .config.template .config; \
		echo "✅ Configuration file created at .config"; \
		echo "⚠️  Please edit .config with your HEP credentials before running data pipeline"; \
	else \
		echo "✅ Configuration file already exists"; \
	fi

# Data pipeline targets
scrape: config
	@echo "🔄 Smart scraping HEP data..."
	@if [ ! -f .config ]; then echo "❌ No .config file found. Run 'make config' first."; exit 1; fi
	source .config && bash ./scripts/get-hep-data.sh
	@echo "✅ Smart scraping complete"

import:
	@echo "📊 Importing data into SQLite database..."
	bash ./scripts/db-import.sh
	@echo "✅ Data import complete"

query:
	@echo "📈 Running database queries..."
	bash ./scripts/db-query.sh
	@echo "✅ Query reports complete"

pipeline: scrape import query
	@echo "✅ Full data pipeline complete"

# Application targets
analytics: install
	@echo "🚀 Starting HEP Energy Analytics Dashboard..."
	@echo "📊 Dashboard will be available at: http://localhost:8080"
	@echo "⏹️  Press Ctrl+C to stop the server"
	@echo ""
	bash ./scripts/run_analytics.sh

legacy: install
	@echo "🚀 Starting legacy Flask application..."
	@echo "📊 App will be available at: http://localhost:5000"
	@echo "⏹️  Press Ctrl+C to stop the server"
	@echo ""
	source .venv/bin/activate && cd app && python app.py

grafana:
	@echo "🐳 Starting Grafana visualization..."
	@echo "📈 Grafana Dashboard: http://localhost:3000 (admin/admin)"
	@echo "📊 Analytics Dashboard: http://localhost:8080"
	@echo "⏹️  Press Ctrl+C to stop services"
	@echo ""
	cd grafana && docker-compose up

# Maintenance targets
clean:
	@echo "🧹 Cleaning up generated files..."
	rm -f data/csv/*.csv
	rm -f data/database/hep.db
	rm -f *.log
	@echo "✅ Cleanup complete"

reset: clean
	@echo "🔄 Resetting everything..."
	rm -rf .venv
	@echo "✅ Reset complete. Your .config file with credentials has been preserved."

reset-all: clean
	@echo "🔄 Resetting everything including credentials..."
	rm -rf .venv
	rm -f .config
	@echo "✅ Complete reset done. Run 'make setup' to start over."

# All-in-one target
all: config
	@echo ""
	@echo "🎯 Starting complete HEP Energy Analytics workflow..."
	@echo ""
	@if [ ! -f .config ]; then \
		echo "⚠️  Configuration file created but needs your HEP credentials."; \
		echo "    Please edit .config with your username, password, and OIB."; \
		echo "    Then run 'make all' again to get data and start the dashboard."; \
		echo ""; \
		echo "📖 For testing without scraping, set HEP_OFFLINE=1 in .config"; \
	else \
		echo "📊 Step 1: Getting latest HEP data..."; \
		$(MAKE) pipeline && \
		echo "🚀 Step 2: Starting analytics dashboard..."; \
		$(MAKE) analytics; \
	fi

# Development helpers
test-config:
	@echo "🔍 Testing configuration..."
	@if [ -f .config ]; then \
		source .config && echo "✅ Config loaded successfully"; \
		source .config && echo "📋 Username: $$HEP_USERNAME"; \
		source .config && echo "📋 OIB: $$HEP_OIB"; \
		source .config && echo "📋 Start Month: $$START_MONTH"; \
		source .config && echo "📋 Start Day: $$START_DAY"; \
		source .config && echo "📋 Offline Mode: $${HEP_OFFLINE:-disabled}"; \
	else \
		echo "❌ No .config file found. Run 'make config' first."; \
	fi

lint: install
	@echo "🔍 Running code quality checks..."
	.venv/bin/python -m py_compile app/app_analytics.py
	.venv/bin/python -m py_compile app/app.py
	@echo "✅ Python syntax check passed"

serve-help:
	@echo "🆘 Quick start help:"
	@echo ""
	@echo "1. First time setup:"
	@echo "   make all"
	@echo ""
	@echo "2. Edit .config with your HEP credentials"
	@echo ""
	@echo "3. Get data and start dashboard:"
	@echo "   make pipeline && make analytics"
	@echo ""
	@echo "4. Or test without scraping (offline mode):"
	@echo "   echo 'HEP_OFFLINE=1' >> .config"
	@echo "   make analytics"