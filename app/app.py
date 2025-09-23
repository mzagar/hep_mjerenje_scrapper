from flask import Flask, render_template, jsonify
import sqlite3
from datetime import datetime

app = Flask(__name__)

def get_db_connection():
    conn = sqlite3.connect('../data/database/hep.db')
    conn.row_factory = sqlite3.Row
    return conn

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
    return render_template('index.html')

@app.route('/api/data')
def get_data():
    conn = get_db_connection()
    try:
        data = conn.execute('''
            SELECT
                timestamp,
                produced,
                returned
            FROM measurements
            ORDER BY timestamp
        ''').fetchall()

        return jsonify({
            'labels': [row['timestamp'] for row in data],
            'produced': [row['produced'] for row in data],
            'returned': [row['returned'] for row in data]
        })
    finally:
        conn.close()

if __name__ == '__main__':
    init_db()
    app.run(debug=True) 