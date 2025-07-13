#!/bin/bash

# Configuration file paths
CONFIG_FILE="$HOME/.marzban_backup_config"
BACKUP_DIR="/tmp/marzban_backups"
LOG_FILE="/var/log/marzban_backup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check and load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

# Function to get user input for configuration
get_user_input() {
    echo "Please enter the following information:"
    read -p "Telegram Bot Token: " TELEGRAM_TOKEN
    read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID
    read -p "Backup interval (in hours): " BACKUP_INTERVAL

    # Save configuration to file
    echo "TELEGRAM_TOKEN='$TELEGRAM_TOKEN'" > "$CONFIG_FILE"
    echo "TELEGRAM_CHAT_ID='$TELEGRAM_CHAT_ID'" >> "$CONFIG_FILE"
    echo "BACKUP_INTERVAL='$BACKUP_INTERVAL'" >> "$CONFIG_FILE"
    
    log_message "New configuration saved"
}

# Function to create backup
create_backup() {
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Backup file name with timestamp
    BACKUP_FILE="$BACKUP_DIR/marzban_backup_$(date '+%Y%m%d_%H%M%S').tar.gz"
    
    # Create backup
    tar -czf "$BACKUP_FILE" /var/lib/marzban/ /op/marzban/ 2>> "$LOG_FILE"
    
    if [[ $? -eq 0 ]]; then
        log_message "Backup created successfully: $BACKUP_FILE"
        send_to_telegram "$BACKUP_FILE"
    else
        log_message "Error creating backup"
        echo "Error creating backup. Please check the log file: $LOG_FILE"
        exit 1
    fi
}

# Function to send backup file to Telegram
send_to_telegram() {
    local backup_file="$1"
    curl -s -F chat_id="$TELEGRAM_CHAT_ID" \
         -F document=@"$backup_file" \
         "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" >> "$LOG_FILE" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_message "Backup file sent to Telegram"
        # Remove temporary backup file after sending
        rm -f "$backup_file"
        log_message "Temporary backup file deleted"
    else
        log_message "Error sending file to Telegram"
        echo "Error sending file to Telegram. Please check the log file: $LOG_FILE"
    fi
}

# Function to set up cron job
setup_cron() {
    local script_path="$0"
    local cron_interval="0 */$BACKUP_INTERVAL * * *"
    local cron_job="$cron_interval bash $script_path --run-backup"
    
    # Remove previous cron job if exists
    crontab -l 2>/dev/null | grep -v "$script_path" > /tmp/crontab_tmp
    echo "$cron_job" >> /tmp/crontab_tmp
    crontab /tmp/crontab_tmp
    rm -f /tmp/crontab_tmp
    
    log_message "Cron job set up successfully: every $BACKUP_INTERVAL hours"
    echo "Cron job set up: every $BACKUP_INTERVAL hours"
}

# Check command-line arguments
if [[ "$1" == "--run-backup" ]]; then
    # Load configuration
    if ! load_config; then
        echo "Error: Configuration file not found!"
        exit 1
    fi
    
    # Run backup
    create_backup
    exit 0
fi

# Main script execution
echo "Marzban Automatic Backup Setup Script"

# Load configuration or prompt user for input
if ! load_config; then
    get_user_input
    load_config
fi

# Set up cron job
setup_cron

# Run initial backup
create_backup

echo "Setup completed successfully. Initial backup sent."
echo "Check the log file for details: $LOG_FILE"
