#!/bin/bash

# --- Remove Windows CR characters from this script on the fly ---
# This avoids issues with ^M or \r characters from Windows line endings
if grep -q $'\r' "$0"; then
    echo "Detected Windows-style line endings, fixing..."
    sed -i 's/\r$//' "$0"
    echo "Fixed line endings. Please run the script again."
    exit 0
fi

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
    curl -s -F chat_id="$TELEGRAM_CHAT_ID" -F document=@"$backup_file" \
        "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" > /dev/null
}

# Function to create compressed backup
create_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="/tmp/marzban_backup_$timestamp.tar.gz"
    tar -czf "$backup_file" /var/lib/marzban/ /opt/marzban/ 2>/dev/null
    echo "$backup_file"
}

# Setup cron job
setup_cron() {
    local interval="$1"
    local cron_cmd="0 */$interval * * * /bin/bash $0 --run-backup"
    (crontab -l 2>/dev/null | grep -v -F "$0"; echo "$cron_cmd") | crontab -
}

# Backup execution mode
if [ "$1" = "--run-backup" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file not found. Please run the script without parameters first."
        exit 1
    fi
    read_config
    backup_file=$(create_backup)
    send_backup "$backup_file"
    rm -f "$backup_file"
    exit 0
fi

echo "Welcome to Marzban Backup Script"
echo "--------------------------------"

if [ -f "$CONFIG_FILE" ]; then
    read_config
    echo -e "\nExisting configuration found:"
    echo "Bot Token: $TELEGRAM_BOT_TOKEN"
    echo "Chat ID: $TELEGRAM_CHAT_ID"
    echo "Backup interval: every $BACKUP_INTERVAL_HOURS hour(s)"

    read -p "Do you want to use the existing settings? (y/n) " use_existing
    if [ "$use_existing" != "y" ]; then
        rm -f "$CONFIG_FILE"
    fi
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\nPlease enter the required information:\n"

    read -p "Telegram bot token: " bot_token
    read -p "Telegram numeric chat ID: " chat_id
    read -p "Backup sending interval (hours): " interval

    save_config "$bot_token" "$chat_id" "$interval"
    echo -e "\nSettings saved successfully!"
fi

read_config

echo -e "\nCreating the first backup..."
backup_file=$(create_backup)
echo "Backup created: $backup_file"
echo "Sending backup to Telegram..."
send_backup "$backup_file"
rm -f "$backup_file"
echo "Backup sent successfully!"

setup_cron "$BACKUP_INTERVAL_HOURS"
echo -e "\nCron job has been set!"
echo "Backup will run every $BACKUP_INTERVAL_HOURS hour(s)"
echo -e "\nOperation completed!"
