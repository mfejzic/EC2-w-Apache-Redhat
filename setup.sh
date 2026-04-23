#!/bin/bash

# Update the system
sudo yum update -y

# Install Java 11 (required for Tomcat and the Java app)
sudo yum install -y java-11-openjdk-devel

# Install Apache HTTP Server (as a reverse proxy)
sudo yum install -y httpd

# Install Tomcat (servlet container for the Java web app)
sudo yum install -y tomcat tomcat-webapps tomcat-admin-webapps

# Enable and start services
sudo systemctl enable httpd tomcat
sudo systemctl start httpd tomcat

# Configure firewall (allow HTTP internally)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# Configure Apache to proxy to Tomcat
echo "ProxyPass / http://localhost:8080/" | sudo tee -a /etc/httpd/conf.d/tomcat.conf
echo "ProxyPassReverse / http://localhost:8080/" | sudo tee -a /etc/httpd/conf.d/tomcat.conf
sudo systemctl restart httpd

# Deploy the WAR file (assuming it's copied to ~/message-board.war)
sudo cp ~/message-board.war /usr/share/tomcat/webapps/ROOT.war
sudo systemctl restart tomcat

# Install psql
sudo yum install -y postgresql

# Create schema --- endpoint subject to change
psql -h my-postgres-db.cguvgyikspim.us-east-1.rds.amazonaws.com -U adminuser -d main -c "CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, message TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

# Install and configure CloudWatch Agent for monitoring
sudo yum install -y amazon-cloudwatch-agent
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cat <<EOF | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "namespace": "RedHatApp",
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_idle"] },
      "mem": { "measurement": ["mem_used_percent"] }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/tomcat/catalina.out", "log_group_name": "tomcat-logs" }
        ]
      }
    }
  }
}
EOF
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Set environment variables for PostgreSQL RDS connection - endpoint subject to change
echo "DB_URL=jdbc:postgresql://my-postgres-db.cguvgyikspim.us-east-1.rds.amazonaws.com:5432/main" | sudo tee -a /etc/environment
echo "DB_USER=adminuser" | sudo tee -a /etc/environment
echo "DB_PASS=password1" | sudo tee -a /etc/environment
sudo systemctl restart tomcat

