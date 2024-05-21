#!/bin/bash

# Ensure the API key is provided
if [ -z "$DATADOG_API_KEY" ]; then
  echo "Error: DATADOG_API_KEY environment variable is not set."
  exit 1
fi

# Step 1: Create the Python Script
cat << 'EOF' > /usr/local/bin/generate_log.py
import xml.etree.ElementTree as ET
from xml.dom import minidom
from datetime import datetime
import random
import time

def prettify_xml(element):
    """Return a pretty-printed XML string for the Element."""
    rough_string = ET.tostring(element, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")

def generate_log_entry():
    """Generate a single XML log entry."""
    entry = ET.Element('LogEntry')
    timestamp = ET.SubElement(entry, 'Timestamp')
    timestamp.text = datetime.now().isoformat()
    message = ET.SubElement(entry, 'Message')
    message.text = 'Sample log message'
    user_id = ET.SubElement(entry, 'UserID')
    user_id.text = str(random.randint(1000, 9999))
    error_code = ET.SubElement(entry, 'ErrorCode')
    error_code.text = str(random.randint(1, 100))
    return entry

def continuously_generate_xml_log():
    """Continuously generate and append XML log entries to a file."""
    file_path = '/var/log/continuous_xml_log.xml'
    while True:
        entry = generate_log_entry()
        with open(file_path, 'a') as file:
            file.write(prettify_xml(entry))
        time.sleep(1)  # Pause for 1 second before the next log entry

# Run the continuous log generation
continuously_generate_xml_log()
EOF

# Make the Python script executable
chmod +x /usr/local/bin/generate_log.py

# Step 2: Create a Systemd Service
cat << 'EOF' > /etc/systemd/system/generate_log.service
[Unit]
Description=Generate XML Logs Continuously

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/generate_log.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable generate_log.service
systemctl start generate_log.service

# Step 3: Install Datadog Agent
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$DATADOG_API_KEY DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Step 4: Configure Datadog Agent to Monitor the Log File
mkdir -p /etc/datadog-agent/conf.d/custom_log.d
cat << 'EOF' > /etc/datadog-agent/conf.d/custom_log.d/conf.yaml
logs:
  - type: file
    path: /var/log/continuous_xml_log.xml
    service: custom_service
    source: python
EOF

# Ensure Datadog Agent log collection is enabled
sed -i 's/^# logs_enabled: false/logs_enabled: true/' /etc/datadog-agent/datadog.yaml

# Restart Datadog Agent to apply changes
systemctl restart datadog-agent

# Verify Datadog Agent status
systemctl status datadog-agent

echo "Setup complete. The log generation script is running as a service and Datadog is monitoring the log file."
