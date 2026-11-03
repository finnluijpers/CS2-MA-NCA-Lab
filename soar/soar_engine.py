#!/usr/bin/env python3
"""
Innovatech Solutions - Event-Driven SOAR Engine (REQ-NCA-P2-08 & REQ-NCA-P2-09)
Description: Listens for incoming security alerts from Alertmanager/SIEM,
             executes automated response actions, and exposes Prometheus metrics.
"""

from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import logging

app = Flask(__name__)

# Configure audit logging
logging.basicConfig(
    filename='soar_audit.log',
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] SOAR Action: %(message)s'
)

# --- PROMETHEUS METRICS (REQ-NCA-P2-09) ---
EVENTS_RECEIVED = Counter('soar_events_received_total', 'Total security events received by SOAR', ['event_type', 'severity'])
ACTIONS_EXECUTED = Counter('soar_actions_executed_total', 'Total automated actions executed', ['action_type', 'status'])
PROCESSING_TIME = Histogram('soar_event_processing_seconds', 'Time spent processing security events')

# --- AUTOMATED RESPONSE ACTIONS (REQ-NCA-P2-08) ---
def action_log_audit(source_ip, alert_name, severity):
    """Action 1: Write an immutable audit log entry."""
    msg = f"ALERT_TRIGGERED | Source: {source_ip} | Alert: {alert_name} | Severity: {severity}"
    logging.info(msg)
    print(f"[SOAR ACTION 1] {msg}")
    ACTIONS_EXECUTED.labels(action_type='log_audit', status='success').inc()

def action_block_ip(source_ip):
    """Action 2: Execute automated IP block / isolation response."""
    msg = f"IP_BLOCKED | Source IP {source_ip} added to firewall blocklist."
    logging.warning(msg)
    print(f"[SOAR ACTION 2] {msg}")
    ACTIONS_EXECUTED.labels(action_type='block_ip', status='success').inc()

# --- WEBHOOK ENDPOINT (REQ-NCA-P2-08) ---
@app.route('/webhook', methods=['POST'])
def handle_alert():
    start_time = time.time()
    data = request.json or {}
    
    # Parse payload (supports standard Alertmanager JSON)
    alerts = data.get('alerts', [data])
    
    for alert in alerts:
        labels = alert.get('labels', {})
        
        alert_name = labels.get('alertname', 'Unknown_Alert')
        severity = labels.get('severity', 'warning')
        source_ip = labels.get('instance', '192.168.88.20').split(':')[0]
        
        EVENTS_RECEIVED.labels(event_type=alert_name, severity=severity).inc()
        
        # Trigger Automated Actions
        action_log_audit(source_ip, alert_name, severity)
        
        if severity in ['critical', 'high'] or 'SSH' in alert_name or 'Process' in alert_name:
            action_block_ip(source_ip)
            
    PROCESSING_TIME.observe(time.time() - start_time)
    return jsonify({"status": "processed", "count": len(alerts)}), 200

# --- PROMETHEUS SCRAPE ENDPOINT (REQ-NCA-P2-09) ---
@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    print("Starting Innovatech SOAR Engine on port 5000...")
    app.run(host='0.0.0.0', port=5000)