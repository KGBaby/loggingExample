#!/bin/bash

# Ensure the API key is provided
if [ -z "$DATADOG_API_KEY" ]; then
  echo "Error: DATADOG_API_KEY environment variable is not set."
  exit 1
fi

# Step 1: Create the Python Script
# Step 1: Create the Python Script
sudo bash -c 'cat << EOF > /usr/local/bin/generate_log.py
import json
from datetime import datetime
import random
import time

def generate_random_ip():
    """Generate a random IP address."""
    return ".".join(str(random.randint(0, 255)) for _ in range(4))

def generate_log_entry():
    """Generate a single JSON log entry."""
    log_entry = {
        "Timestamp": datetime.now().isoformat(),
        "Message": "Sample log message",
        "UserID": random.randint(1000, 9999),
        "ErrorCode": random.randint(1, 100),
        "Status": random.choice(["error", "info"]),
        "Network": {
            "Client": {
                "IP": generate_random_ip()
            }
        }
    }
    return log_entry

def continuously_generate_json_log():
    """Continuously generate and append JSON log entries to a file."""
    file_path = "/var/log/continuous_json_log.json"
    while True:
        entry = generate_log_entry()
        with open(file_path, "a") as file:
            file.write(json.dumps(entry, indent=2) + "\n")
        time.sleep(1)  # Pause for 1 second before the next log entry

# Run the continuous log generation
continuously_generate_json_log()
EOF'


# Make the Python script executable
sudo chmod +x /usr/local/bin/generate_log.py

# Step 2: Create a Systemd Service
sudo bash -c 'cat << EOF > /etc/systemd/system/generate_log.service
[Unit]
Description=Generate XML Logs Continuously

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/generate_log.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable generate_log.service
sudo systemctl start generate_log.service

# Step 3: Install Datadog Agent
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$DATADOG_API_KEY DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Step 4: Configure Datadog Agent to Monitor the Log File
sudo mkdir -p /etc/datadog-agent/conf.d/custom_log.d
sudo bash -c 'cat << EOF > /etc/datadog-agent/conf.d/custom_log.d/conf.yaml
logs:
  - type: file
    path: /var/log/continuous_xml_log.xml
    service: custom_service
    source: python
EOF'

# Ensure Datadog Agent log collection is enabled
sudo sed -i 's/^# logs_enabled: false/logs_enabled: true/' /etc/datadog-agent/datadog.yaml

# Restart Datadog Agent to apply changes
sudo systemctl restart datadog-agent

# Verify Datadog Agent status
sudo systemctl status datadog-agent

echo "Setup complete. The log generation script is running as a service and Datadog is monitoring the log file."
