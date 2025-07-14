#!/bin/bash

# Marzban Backup Script
# =====================
# This script is for automatic backups of Marzban paths.
# Features:
# - Install prerequisites at the beginning.
# - Store initial settings in a config file for subsequent runs.
# - Create tar.gz backup of specified paths.
# - Send backup to Telegram via Bot API.
# - Set up cron job for periodic execution.
# - Perform initial backup after setup.
# - All script messages in Persian for Persian-speaking users.
#
# Requirements: Ubuntu 20.04 or higher. Run with sudo.
# Usage: sudo bash backup_marzban.sh
# For cron execution: sudo bash backup_marzban.sh --auto
#
# Author: [Your name or alias] - For GitHub
# License: MIT (or your preferred license)

# Colors for nicer output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No color

# Config file path
CONFIG_FILE="$HOME/.marzban_backup_config"

# Function to display error and exit
error_exit() {
    echo -e "${RED}خطا: $1${NC}"
    exit 1
}

# Install prerequisites
echo "در حال بررسی و نصب پیش‌نیازها..."
sudo apt update -y || error_exit "به‌روزرسانی لیست پکیج‌ها شکست خورد."
sudo apt install -y curl tar cron || error_exit "نصب پکیج‌ها شکست خورد."
echo -e "${GREEN}پیش‌نیازها با موفقیت نصب شدند.${NC}"

# Check if argument is --auto (for cron run without interaction)
if [ "$1" == "--auto" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        error_exit "فایل کانفیگ وجود ندارد. ابتدا اسکریپت را بدون آرگومان اجرا کنید."
    fi
    source "$CONFIG_FILE"
    # Proceed to backup section
else
    # Initial setup if config file doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "تنظیمات اولیه اسکریپت:"
        read -p "توکن ربات تلگرام را وارد کنید: " TELEGRAM_TOKEN
        read -p "آیدی عددی چت تلگرام را وارد کنید: " TELEGRAM_CHAT_ID
        read -p "هر چند ساعت یک‌بار بکاپ گرفته شود؟ (عدد ساعت، مثلاً 6): " BACKUP_INTERVAL

        # Simple input validation
        if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" || ! "$BACKUP_INTERVAL" =~ ^[0-9]+$ ]]; then
            error_exit "ورودی‌های نامعتبر. لطفاً مقادیر صحیح وارد کنید."
        fi

        # Save to config file
        echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" > "$CONFIG_FILE"
        echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> "$CONFIG_FILE"
        echo "BACKUP_INTERVAL=$BACKUP_INTERVAL" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"  # Secure the file
        echo -e "${GREEN}تنظیمات ذخیره شدند.${NC}"
    else
        source "$CONFIG_FILE"
        echo "تنظیمات از فایل کانفیگ بارگذاری شدند."
    fi

    # Set up cron job (persistent, survives reboots)
    SCRIPT_PATH=$(realpath "$0")
    CRON_JOB="0 */$BACKUP_INTERVAL * * * sudo bash $SCRIPT_PATH --auto"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab - || error_exit "تنظیم کرون‌جاب شکست خورد."
    echo -e "${GREEN}کرون‌جاب تنظیم شد: هر $BACKUP_INTERVAL ساعت یک‌بار.${NC}"
fi

# Create backup
echo "در حال ایجاد بکاپ..."
BACKUP_DIR="/tmp/marzban_backups"
mkdir -p "$BACKUP_DIR" || error_exit "ایجاد دایرکتوری بکاپ شکست خورد."
BACKUP_FILE="$BACKUP_DIR/marzban_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

tar -czf "$BACKUP_FILE" /var/lib/marzban/ /op/marzban/ || error_exit "ایجاد فایل بکاپ شکست خورد."
echo -e "${GREEN}بکاپ با موفقیت ایجاد شد: $BACKUP_FILE${NC}"

# Send to Telegram
echo "در حال ارسال بکاپ به تلگرام..."
RESPONSE=$(curl -s -F chat_id="$TELEGRAM_CHAT_ID" -F document=@"$BACKUP_FILE" "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument")

# Check send success
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo -e "${GREEN}بکاپ با موفقیت به تلگرام ارسال شد.${NC}"
else
    error_exit "ارسال به تلگرام شکست خورد. پاسخ: $RESPONSE"
fi

# Clean up local backup file (optional, to avoid filling space)
rm -f "$BACKUP_FILE"
echo "فایل بکاپ محلی پاک شد."

# Script end
echo -e "${GREEN}عملیات با موفقیت به پایان رسید.${NC}"
