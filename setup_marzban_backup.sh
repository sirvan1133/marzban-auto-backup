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

# Main setup interface (Persian messages)
echo "به اسکریپت پشتیبان‌گیری Marzban خوش آمدید"
echo "---------------------------------------"

# Check for existing configuration
if [ -f "$CONFIG_FILE" ]; then
    read_config
    echo -e "\nتنظیمات قبلی پیدا شد:"
    echo "توکن ربات: $TELEGRAM_BOT_TOKEN"
    echo "آیدی چت: $TELEGRAM_CHAT_ID"
    echo "فاصله زمانی: هر $BACKUP_INTERVAL_HOURS ساعت"
    
    read -p "آیا می‌خواهید از تنظیمات قبلی استفاده کنید؟ (y/n) " use_existing
    if [ "$use_existing" != "y" ]; then
        rm -f "$CONFIG_FILE"  # Remove existing config
    fi
fi

# Get new configuration if needed
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\nلطفاً اطلاعات مورد نیاز را وارد کنید:\n"
    
    read -p "توکن ربات تلگرام: " bot_token
    read -p "آیدی عددی چت تلگرام: " chat_id
    read -p "فاصله زمانی ارسال بکاپ (ساعت): " interval
    
    save_config "$bot_token" "$chat_id" "$interval"
    echo -e "\nتنظیمات با موفقیت ذخیره شد!"
fi

# Load configuration
read_config

# Create immediate backup
echo -e "\nدر حال ایجاد اولین پشتیبان..."
backup_file=$(create_backup)
echo "پشتیبان ایجاد شد: $backup_file"
echo "در حال ارسال به تلگرام..."
send_backup "$backup_file"
rm -f "$backup_file"
echo "ارسال با موفقیت انجام شد!"

# Setup cron job
setup_cron "$BACKUP_INTERVAL_HOURS"
echo -e "\nکرون جاب تنظیم شد!"
echo "پشتیبان‌گیری هر $BACKUP_INTERVAL_HOURS ساعت یکبار انجام خواهد شد"
echo -e "\nاتمام عملیات!"
