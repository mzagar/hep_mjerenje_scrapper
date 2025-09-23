from flask import Flask, render_template, jsonify, request
import sqlite3
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import re

app = Flask(__name__)

def get_db_connection():
    conn = sqlite3.connect('../data/database/hep.db')
    conn.row_factory = sqlite3.Row
    return conn

def validate_days_parameter(days, min_days=1, max_days=3650):
    """Validate and clamp days parameter to safe range"""
    if days is None:
        return 30  # Default fallback
    return max(min_days, min(days, max_days))

def detect_period_type_and_calculate_previous(start_date, end_date):
    """
    Detect the type of period and calculate the equivalent previous period for comparison
    Returns: (period_type, prev_start, prev_end, comparison_label)
    """
    start_dt = datetime.strptime(start_date, '%Y-%m-%d')
    end_dt = datetime.strptime(end_date, '%Y-%m-%d')
    period_days = (end_dt - start_dt).days + 1

    # Detect period type based on dates and duration
    today = datetime.now().date()
    start_date_obj = start_dt.date()
    end_date_obj = end_dt.date()

    # Check if it's "this" period (ends today or very recently)
    is_current_period = (today - end_date_obj).days <= 1

    # Monthly periods
    if (start_date_obj.day == 1 and
        (end_date_obj.month != start_date_obj.month or end_date_obj.day >= 28)):
        if is_current_period:
            # This month vs last month
            prev_start = datetime(start_dt.year if start_dt.month > 1 else start_dt.year - 1,
                                start_dt.month - 1 if start_dt.month > 1 else 12, 1)
            if start_dt.month > 1:
                prev_end = datetime(start_dt.year, start_dt.month, 1) - timedelta(days=1)
            else:
                prev_end = datetime(start_dt.year - 1, 12, 31)
            return ("this_month", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs last month")
        else:
            # Specific month vs same month previous year
            prev_start = datetime(start_dt.year - 1, start_dt.month, start_dt.day)
            prev_end = datetime(end_dt.year - 1, end_dt.month, end_dt.day)
            return ("specific_month", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs same month last year")

    # Quarterly periods (roughly 90 days and starts near quarter boundaries)
    if 85 <= period_days <= 95:
        prev_start = start_dt - timedelta(days=period_days)
        prev_end = end_dt - timedelta(days=period_days)
        if is_current_period:
            return ("this_quarter", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs last quarter")
        else:
            return ("specific_quarter", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous quarter")

    # Yearly periods
    if 360 <= period_days <= 370:
        if start_date_obj.month == 1 and start_date_obj.day == 1:
            # Calendar year
            prev_start = datetime(start_dt.year - 1, 1, 1)
            prev_end = datetime(start_dt.year - 1, 12, 31)
            if is_current_period:
                return ("this_year", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs last year")
            else:
                return ("specific_year", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous year")
        else:
            # Rolling year
            prev_start = start_dt - timedelta(days=365)
            prev_end = end_dt - timedelta(days=365)
            return ("rolling_year", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous year")

    # Weekly periods
    if 6 <= period_days <= 8:
        prev_start = start_dt - timedelta(days=period_days)
        prev_end = end_dt - timedelta(days=period_days)
        if is_current_period:
            return ("this_week", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs last week")
        else:
            return ("specific_week", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous week")

    # Common rolling periods
    if period_days == 7:
        prev_start = start_dt - timedelta(days=7)
        prev_end = end_dt - timedelta(days=7)
        return ("last_7_days", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous 7 days")
    elif period_days == 30:
        prev_start = start_dt - timedelta(days=30)
        prev_end = end_dt - timedelta(days=30)
        return ("last_30_days", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous 30 days")
    elif period_days == 90:
        prev_start = start_dt - timedelta(days=90)
        prev_end = end_dt - timedelta(days=90)
        return ("last_90_days", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), "vs previous 90 days")

    # Default: rolling period comparison
    prev_start = start_dt - timedelta(days=period_days)
    prev_end = end_dt - timedelta(days=period_days)
    return ("custom_period", prev_start.strftime('%Y-%m-%d'), prev_end.strftime('%Y-%m-%d'), f"vs previous {period_days} days")

def init_db():
    conn = get_db_connection()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS measurements (
            timestamp DATETIME,
            produced FLOAT,
            returned FLOAT
        )
    ''')
    conn.commit()
    conn.close()

@app.route('/')
def index():
    return render_template('analytics.html')

# Original endpoint for backward compatibility
@app.route('/api/data')
def get_data():
    conn = get_db_connection()
    # Use the new daily_data view for better performance
    data = conn.execute('''
        SELECT
            datum as date,
            consumed_kwh as consumed,
            produced_kwh as produced,
            net_kwh as net
        FROM daily_data
        ORDER BY datum
    ''').fetchall()
    conn.close()

    return jsonify({
        'labels': [row['date'] for row in data],
        'consumed': [float(row['consumed']) for row in data],
        'produced': [float(row['produced']) for row in data],
        'net': [float(row['net']) for row in data]
    })

@app.route('/api/overview')
def get_overview():
    """Get key metrics overview with intelligent period comparison"""
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')

    conn = get_db_connection()

    # Build query for current period
    query = '''
        SELECT
            SUM(consumed_kwh) as total_consumed,
            SUM(produced_kwh) as total_produced,
            SUM(net_kwh) as total_net,
            AVG(self_consumption_ratio) as avg_self_consumption,
            COUNT(*) as total_days,
            MIN(datum) as start_date,
            MAX(datum) as end_date
        FROM daily_data
        WHERE 1=1
    '''
    params = []

    if start_date:
        query += ' AND datum >= ?'
        params.append(start_date)

    if end_date:
        query += ' AND datum <= ?'
        params.append(end_date)

    # Get current period statistics
    current_totals = conn.execute(query, params).fetchone()

    # Get recent trends (last 30 days for context)
    recent_trend = conn.execute('''
        SELECT
            AVG(consumed_kwh) as avg_daily_consumed,
            AVG(produced_kwh) as avg_daily_produced,
            MAX(consumed_kwh) as max_daily_consumed,
            MIN(consumed_kwh) as min_daily_consumed
        FROM daily_data
        WHERE datum >= date('now', '-30 days')
    ''').fetchone()

    # Calculate period comparison if we have date range
    period_comparison = {}
    if start_date and end_date:
        try:
            # Detect period type and calculate previous period
            period_type, prev_start, prev_end, comparison_label = detect_period_type_and_calculate_previous(start_date, end_date)

            # Query previous period data
            prev_query = '''
                SELECT
                    SUM(consumed_kwh) as total_consumed,
                    SUM(produced_kwh) as total_produced,
                    SUM(net_kwh) as total_net,
                    AVG(self_consumption_ratio) as avg_self_consumption,
                    COUNT(*) as total_days
                FROM daily_data
                WHERE datum >= ? AND datum <= ?
            '''
            prev_totals = conn.execute(prev_query, [prev_start, prev_end]).fetchone()

            # Calculate percentage changes
            if prev_totals and prev_totals['total_days'] > 0:
                def calc_change(current, previous):
                    if previous and previous > 0:
                        return ((current - previous) / previous) * 100
                    return 0

                period_comparison = {
                    'consumed_change': calc_change(current_totals['total_consumed'] or 0, prev_totals['total_consumed'] or 0),
                    'produced_change': calc_change(current_totals['total_produced'] or 0, prev_totals['total_produced'] or 0),
                    'net_change': calc_change(current_totals['total_net'] or 0, prev_totals['total_net'] or 0),
                    'self_consumption_change': calc_change(current_totals['avg_self_consumption'] or 0, prev_totals['avg_self_consumption'] or 0),
                    'comparison_label': comparison_label,
                    'period_type': period_type,
                    'previous_period': {
                        'start': prev_start,
                        'end': prev_end,
                        'days': prev_totals['total_days']
                    }
                }
        except Exception as e:
            print(f"Error calculating period comparison: {e}")
            period_comparison = {}

    conn.close()

    return jsonify({
        'totals': {
            'consumed': float(current_totals['total_consumed'] or 0),
            'produced': float(current_totals['total_produced'] or 0),
            'net': float(current_totals['total_net'] or 0),
            'self_consumption_ratio': float(current_totals['avg_self_consumption'] or 0),
            'total_days': current_totals['total_days'],
            'date_range': {
                'start': current_totals['start_date'],
                'end': current_totals['end_date']
            }
        },
        'recent_trends': {
            'avg_daily_consumed': float(recent_trend['avg_daily_consumed'] or 0),
            'avg_daily_produced': float(recent_trend['avg_daily_produced'] or 0),
            'max_daily_consumed': float(recent_trend['max_daily_consumed'] or 0),
            'min_daily_consumed': float(recent_trend['min_daily_consumed'] or 0)
        },
        'period_comparison': period_comparison
    })

@app.route('/api/daily')
def get_daily_data():
    """Get daily aggregated data with optional date filtering"""
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')

    conn = get_db_connection()

    query = '''
        SELECT * FROM daily_data
        WHERE 1=1
    '''
    params = []

    if start_date:
        query += ' AND datum >= ?'
        params.append(start_date)

    if end_date:
        query += ' AND datum <= ?'
        params.append(end_date)

    query += ' ORDER BY datum'

    data = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify([dict(row) for row in data])

@app.route('/api/hourly')
def get_hourly_data():
    """Get hourly aggregated data"""
    date = request.args.get('date')  # Specific date
    days = validate_days_parameter(request.args.get('days', 7, type=int))

    conn = get_db_connection()

    if date:
        query = '''
            SELECT * FROM hourly_data
            WHERE datum = ?
            ORDER BY hour
        '''
        params = [date]
    else:
        query = '''
            SELECT * FROM hourly_data
            WHERE datum >= date('now', '-{} days')
            ORDER BY datetime_hour
        '''.format(days)
        params = []

    data = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify([dict(row) for row in data])

@app.route('/api/monthly')
def get_monthly_data():
    """Get monthly aggregated data"""
    conn = get_db_connection()

    data = conn.execute('''
        SELECT * FROM monthly_data
        ORDER BY month_year
    ''').fetchall()

    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/patterns')
def get_usage_patterns():
    """Get usage patterns (hourly, daily, monthly averages)"""
    pattern_type = request.args.get('type', 'hourly')  # hourly, daily, monthly

    conn = get_db_connection()

    data = conn.execute('''
        SELECT * FROM usage_patterns
        WHERE pattern_type = ?
        ORDER BY CAST(time_unit AS INTEGER)
    ''', [pattern_type.title()]).fetchall()

    conn.close()
    return jsonify([dict(row) for row in data])

@app.route('/api/time-of-use')
def get_time_of_use():
    """Get time-of-use analysis (peak vs off-peak)"""
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')

    conn = get_db_connection()

    query = '''
        SELECT
            tariff_period,
            time_period,
            SUM(consumed_kwh) as total_consumed,
            SUM(produced_kwh) as total_produced,
            SUM(net_kwh) as total_net,
            AVG(consumed_kwh) as avg_consumed,
            AVG(produced_kwh) as avg_produced,
            COUNT(*) as readings
        FROM time_of_use_data
        WHERE 1=1
    '''
    params = []

    if start_date:
        query += ' AND datum >= ?'
        params.append(start_date)

    if end_date:
        query += ' AND datum <= ?'
        params.append(end_date)

    query += '''
        GROUP BY tariff_period, time_period
        ORDER BY
            CASE tariff_period WHEN 'Peak' THEN 1 ELSE 2 END,
            CASE time_period
                WHEN 'Morning' THEN 1
                WHEN 'Midday' THEN 2
                WHEN 'Evening' THEN 3
                ELSE 4
            END
    '''

    data = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify([dict(row) for row in data])

@app.route('/api/efficiency')
def get_efficiency_metrics():
    """Get energy efficiency metrics"""
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    days = validate_days_parameter(request.args.get('days', 30, type=int))

    conn = get_db_connection()

    # Build query with date filtering
    query = '''
        SELECT
            datum,
            energy_independence_pct,
            grid_export_pct,
            self_sufficient_day
        FROM efficiency_metrics
        WHERE 1=1
    '''
    params = []

    if start_date and end_date:
        query += ' AND datum >= ? AND datum <= ?'
        params.extend([start_date, end_date])
    else:
        query += ' AND datum >= date("now", "-{} days")'.format(days)

    query += ' ORDER BY datum'

    # Get efficiency metrics for the specified period
    data = conn.execute(query, params).fetchall()

    # Calculate summary statistics with same date filtering
    summary_query = '''
        SELECT
            AVG(energy_independence_pct) as avg_independence,
            AVG(grid_export_pct) as avg_export,
            SUM(self_sufficient_day) as self_sufficient_days,
            COUNT(*) as total_days
        FROM efficiency_metrics
        WHERE 1=1
    '''

    if start_date and end_date:
        summary_query += ' AND datum >= ? AND datum <= ?'
        summary = conn.execute(summary_query, params).fetchone()
    else:
        summary_query += ' AND datum >= date("now", "-{} days")'.format(days)
        summary = conn.execute(summary_query).fetchone()

    conn.close()

    return jsonify({
        'daily_metrics': [dict(row) for row in data],
        'summary': {
            'avg_energy_independence': float(summary['avg_independence'] or 0),
            'avg_grid_export': float(summary['avg_export'] or 0),
            'self_sufficient_days': int(summary['self_sufficient_days'] or 0),
            'total_days': int(summary['total_days']),
            'self_sufficiency_ratio': float(summary['self_sufficient_days'] or 0) / max(summary['total_days'], 1) * 100
        }
    })

@app.route('/api/comparison')
def compare_periods():
    """Compare two time periods"""
    period1_start = request.args.get('period1_start')
    period1_end = request.args.get('period1_end')
    period2_start = request.args.get('period2_start')
    period2_end = request.args.get('period2_end')

    if not all([period1_start, period1_end, period2_start, period2_end]):
        return jsonify({'error': 'All date parameters required'}), 400

    conn = get_db_connection()

    # Get data for both periods
    period1_data = conn.execute('''
        SELECT
            SUM(consumed_kwh) as consumed,
            SUM(produced_kwh) as produced,
            SUM(net_kwh) as net,
            AVG(self_consumption_ratio) as self_consumption,
            COUNT(*) as days
        FROM daily_data
        WHERE datum BETWEEN ? AND ?
    ''', [period1_start, period1_end]).fetchone()

    period2_data = conn.execute('''
        SELECT
            SUM(consumed_kwh) as consumed,
            SUM(produced_kwh) as produced,
            SUM(net_kwh) as net,
            AVG(self_consumption_ratio) as self_consumption,
            COUNT(*) as days
        FROM daily_data
        WHERE datum BETWEEN ? AND ?
    ''', [period2_start, period2_end]).fetchone()

    conn.close()

    # Calculate percentage changes
    def calc_change(new, old):
        if new is None:
            return 0
        if old and old != 0:
            return ((new - old) / old) * 100
        return 0

    comparison = {
        'period1': {
            'start': period1_start,
            'end': period1_end,
            'consumed': float(period1_data['consumed'] or 0),
            'produced': float(period1_data['produced'] or 0),
            'net': float(period1_data['net'] or 0),
            'self_consumption': float(period1_data['self_consumption'] or 0),
            'days': period1_data['days']
        },
        'period2': {
            'start': period2_start,
            'end': period2_end,
            'consumed': float(period2_data['consumed'] or 0),
            'produced': float(period2_data['produced'] or 0),
            'net': float(period2_data['net'] or 0),
            'self_consumption': float(period2_data['self_consumption'] or 0),
            'days': period2_data['days']
        },
        'changes': {
            'consumed': calc_change(period2_data['consumed'], period1_data['consumed']),
            'produced': calc_change(period2_data['produced'], period1_data['produced']),
            'net': calc_change(period2_data['net'], period1_data['net']),
            'self_consumption': calc_change(period2_data['self_consumption'], period1_data['self_consumption'])
        }
    }

    return jsonify(comparison)

@app.route('/api/financial')
def get_financial_analysis():
    """Calculate costs and savings with configurable Croatian HEP tariffs"""
    # Get tariff parameters from request or use defaults (2024-2025 EUR values)
    tariff_type = request.args.get('tariff_type', 'single')  # 'single' or 'dual'
    single_price = float(request.args.get('single_price', 0.11))
    peak_price = float(request.args.get('peak_price', 0.13))
    offpeak_price = float(request.args.get('offpeak_price', 0.09))
    feed_in_price = float(request.args.get('feed_in_price', 0.07))
    monthly_fee = float(request.args.get('monthly_fee', 20.0))
    netting_ratio = float(request.args.get('netting_ratio', 0.75))

    # Build tariffs object based on type
    if tariff_type == 'single':
        tariffs = {
            'peak_price': single_price,
            'offpeak_price': single_price,
            'feed_in_tariff': feed_in_price * netting_ratio,  # Apply HEP netting ratio
            'monthly_fee': monthly_fee,
            'netting_ratio': netting_ratio
        }
    else:  # dual tariff
        tariffs = {
            'peak_price': peak_price,
            'offpeak_price': offpeak_price,
            'feed_in_tariff': feed_in_price * netting_ratio,  # Apply HEP netting ratio
            'monthly_fee': monthly_fee,
            'netting_ratio': netting_ratio
        }

    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    period_days = validate_days_parameter(request.args.get('days', 30, type=int))

    conn = get_db_connection()

    # Build query with date filtering
    query = '''
        SELECT
            tariff_period,
            SUM(consumed_kwh) as consumed,
            SUM(produced_kwh) as produced,
            SUM(net_kwh) as net
        FROM time_of_use_data
        WHERE 1=1
    '''
    params = []

    if start_date and end_date:
        query += ' AND datum >= ? AND datum <= ?'
        params.extend([start_date, end_date])
        # Calculate period days for projections
        from datetime import datetime
        start_dt = datetime.strptime(start_date, '%Y-%m-%d')
        end_dt = datetime.strptime(end_date, '%Y-%m-%d')
        period_days = (end_dt - start_dt).days + 1
    else:
        query += ' AND datum >= date("now", "-{} days")'.format(period_days)

    query += ' GROUP BY tariff_period'

    # Get time-of-use data for cost calculation
    data = conn.execute(query, params).fetchall()

    # Calculate costs
    total_cost = 0
    total_savings = 0
    total_feed_in = 0

    for row in data:
        price = tariffs['peak_price'] if row['tariff_period'] == 'Peak' else tariffs['offpeak_price']

        # Cost if consuming from grid
        consumption_cost = max(0, row['consumed'] or 0) * price
        total_cost += consumption_cost

        # Savings from self-consumption (what we would have paid)
        self_consumed = max(0, min(row['consumed'] or 0, row['produced'] or 0))
        savings = self_consumed * price
        total_savings += savings

        # Feed-in income from excess production
        excess_production = max(0, (row['produced'] or 0) - (row['consumed'] or 0))
        feed_in_income = excess_production * tariffs['feed_in_tariff']
        total_feed_in += feed_in_income

    # Get totals for the period with same date filtering
    totals_query = '''
        SELECT
            SUM(consumed_kwh) as total_consumed,
            SUM(produced_kwh) as total_produced,
            SUM(net_kwh) as total_net
        FROM daily_data
        WHERE 1=1
    '''

    if start_date and end_date:
        totals_query += ' AND datum >= ? AND datum <= ?'
        totals = conn.execute(totals_query, params).fetchone()
    else:
        totals_query += ' AND datum >= date("now", "-{} days")'.format(period_days)
        totals = conn.execute(totals_query).fetchone()

    conn.close()

    # Calculate monthly fees for the period
    monthly_fee_cost = (tariffs['monthly_fee'] * period_days) / 30.44  # Average days per month

    # Calculate what the total cost would be without solar
    total_without_solar = ((totals['total_consumed'] or 0) + max(0, -(totals['total_net'] or 0))) * np.mean([tariffs['peak_price'], tariffs['offpeak_price']]) + monthly_fee_cost

    # Net cost includes monthly fees
    net_cost = total_cost - total_feed_in + monthly_fee_cost
    total_benefit = total_savings + total_feed_in

    return jsonify({
        'period_days': period_days,
        'tariffs': tariffs,
        'consumption': {
            'total_consumed': float(totals['total_consumed'] or 0),
            'total_produced': float(totals['total_produced'] or 0),
            'total_net': float(totals['total_net'] or 0)
        },
        'costs': {
            'grid_consumption_cost': round(total_cost, 2),
            'feed_in_income': round(total_feed_in, 2),
            'monthly_fees': round(monthly_fee_cost, 2),
            'net_cost': round(net_cost, 2),
            'cost_without_solar': round(total_without_solar, 2)
        },
        'savings': {
            'self_consumption_savings': round(total_savings, 2),
            'total_benefit': round(total_benefit, 2),
            'total_savings_vs_no_solar': round(total_without_solar - net_cost, 2),
            'savings_percentage': round((total_without_solar - net_cost) / total_without_solar * 100, 1) if total_without_solar > 0 else 0
        },
        'projections': {
            'monthly_savings': round((total_without_solar - net_cost) / period_days * 30, 2),
            'yearly_savings': round((total_without_solar - net_cost) / period_days * 365, 2)
        }
    })

if __name__ == '__main__':
    init_db()
    app.run(debug=True, host='0.0.0.0', port=8080)