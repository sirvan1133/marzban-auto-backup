#!/bin/bash

# Configuration file path
CONFIG_FILE="/root/marzban_backup_config.conf"

# Function to save settings to config file
save_config() {
    echo "TELEGRAM_BOT_TOKEN=\"$1\"" > "$CONFIG_FILE"
    echo "TELEGRAM_CHAT_ID=\"$2\"" >> "$CONFIG_FILE"
    echo "BACKUP_INTERVAL_HOURS=\"$3\"" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"  # Secure file permissions
}

# Function to read configuration
read_config() {
    source "$CONFIG_FILE"
}

# Function to send backup to Telegram
send_backup() {
    local backup_file="$1"
    # Send file via Telegram API
    curl -s -F chat_id="$TELEGRAM_CHAT_ID" -F document=@"$backup_file" \
        "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" > /dev/null
}

# Function to create compressed backup
create_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")  # Generate timestamp
    local backup_file="/tmp/marzban_backup_$timestamp.tar.gz"
    # Create compressed archive of both directories
    tar -czf "$backup_file" /var/lib/marzban/ /opt/marzban/ 2>/dev/null
    echo "$backup_file"
}

# Function to setup cron job
setup_cron() {
    local interval="$1"
    # Create cron command with interval
    local cron_cmd="0 */$interval * * * /bin/bash $0 --run-backup"
    # Add to crontab without duplication
    (crontab -l 2>/dev/null | grep -v -F "$0"; echo "$cron_cmd") | crontab -
}

# Backup execution mode
if [ "$1" = "--run-backup" ]; then
    read_config
    backup_file=$(create_backup)
    send_backup "$backup_file"
    rm -f "$backup_file"  # Clean up temporary file
    exit 0
fi

# Main setup interface (English messages)
echo "Welcome to Marzban Backup Script"
echo "-------------------------------"

# Check for existing configuration
if [ -f "$CONFIG_FILE" ]; then
    read_config
    echo -e "\nExisting configuration found:"
    echo "Bot Token: $TELEGRAM_BOT_TOKEN"
    echo "Chat ID: $TELEGRAM_CHAT_ID"
    echo "Backup Interval: every $BACKUP_INTERVAL_HOURS hours"
    
    read -p "Do you want to use existing settings? (y/n) " use_existing
    if [ "$use_existing" != "y" ]; then
        rm -f "$CONFIG_FILE"  # Remove existing config
    fi
fi

# Get new configuration if needed
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\nPlease enter required information:\n"
    
    read -p "Telegram Bot Token: " bot_token
    read -p "Telegram Chat ID: " chat_id
    read -p "Backup interval (hours): " interval
    
    save_config "$bot_token" "$chat_id" "$interval"
    echo -e "\nConfiguration saved successfully!"
fi

# Load configuration
read_config

# Create immediate backup
echo -e "\nCreating first backup..."
backup_file=$(create_backup)
echo "Backup created: $backup_file"
echo "Sending to Telegram..."
send_backup "$backup_file"
rm -f "$backup_file"
echo "Backup sent successfully!"

# Setup cron job
setup_cron "$BACKUP_INTERVAL_HOURS"
echo -e "\nCron job set up!"
echo "Backups will run every $BACKUP_INTERVAL_HOURS hours"
echo -e "\nSetup completed!"
