#!/bin/bash

# Activate virtual environment and run the analytics Flask app
source .venv/bin/activate
export FLASK_APP=app/app_analytics.py
export FLASK_ENV=development

echo "Starting HEP Energy Analytics Dashboard..."
echo "Access the dashboard at: http://localhost:8080"
echo "Press Ctrl+C to stop the server"
echo ""

cd app && python app_analytics.py