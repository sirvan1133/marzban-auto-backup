#!/bin/bash

# فایل تنظیمات
CONFIG_FILE="$HOME/.marzban_backup_config"
BACKUP_DIR="/tmp/marzban_backups"
LOG_FILE="/var/log/marzban_backup.log"

# تابع برای ثبت لاگ
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# تابع برای بررسی وجود فایل تنظیمات و خواندن آن
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        return 0
    else
        return 1
    fi
}

# تابع برای دریافت تنظیمات از کاربر
get_user_input() {
    echo "لطفاً اطلاعات زیر را وارد کنید:"
    read -p "توکن ربات تلگرام: " TELEGRAM_TOKEN
    read -p "آیدی عددی چت تلگرام: " TELEGRAM_CHAT_ID
    read -p "فاصله زمانی بکاپ (به ساعت): " BACKUP_INTERVAL

    # ذخیره تنظیمات در فایل
    echo "TELEGRAM_TOKEN='$TELEGRAM_TOKEN'" > "$CONFIG_FILE"
    echo "TELEGRAM_CHAT_ID='$TELEGRAM_CHAT_ID'" >> "$CONFIG_FILE"
    echo "BACKUP_INTERVAL='$BACKUP_INTERVAL'" >> "$CONFIG_FILE"
    
    log_message "تنظیمات جدید ذخیره شد"
}

# تابع برای ایجاد بکاپ
create_backup() {
    # ایجاد دایرکتوری بکاپ در صورت عدم وجود
    mkdir -p "$BACKUP_DIR"
    
    # نام فایل بکاپ با تاریخ و زمان
    BACKUP_FILE="$BACKUP_DIR/marzban_backup_$(date '+%Y%m%d_%H%M%S').tar.gz"
    
    # ایجاد بکاپ
    tar -czf "$BACKUP_FILE" /var/lib/marzban/ /op/marzban/ 2>> "$LOG_FILE"
    
    if [[ $? -eq 0 ]]; then
        log_message "بکاپ با موفقیت ایجاد شد: $BACKUP_FILE"
        send_to_telegram "$BACKUP_FILE"
    else
        log_message "خطا در ایجاد بکاپ"
        echo "خطا در ایجاد بکاپ. لطفاً لاگ را بررسی کنید: $LOG_FILE"
        exit 1
    fi
}

# تابع برای ارسال فایل به تلگرام
send_to_telegram() {
    local backup_file="$1"
    curl -s -F chat_id="$TELEGRAM_CHAT_ID" \
         -F document=@"$backup_file" \
         "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" >> "$LOG_FILE" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_message "فایل بکاپ به تلگرام ارسال شد"
        # حذف فایل بکاپ بعد از ارسال
        rm -f "$backup_file"
        log_message "فایل بکاپ موقت حذف شد"
    else
        log_message "خطا در ارسال فایل به تلگرام"
        echo "خطا در ارسال فایل به تلگرام. لطفاً لاگ را بررسی کنید: $LOG_FILE"
    fi
}

# تابع برای تنظیم کرون جاب
setup_cron() {
    local script_path="$0"
    local cron_interval="0 */$BACKUP_INTERVAL * * *"
    local cron_job="$cron_interval bash $script_path --run-backup"
    
    # بررسی وجود کرون جاب قبلی
    crontab -l 2>/dev/null | grep -v "$script_path" > /tmp/crontab_tmp
    echo "$cron_job" >> /tmp/crontab_tmp
    crontab /tmp/crontab_tmp
    rm -f /tmp/crontab_tmp
    
    log_message "کرون جاب با موفقیت تنظیم شد: هر $BACKUP_INTERVAL ساعت"
    echo "کرون جاب تنظیم شد: هر $BACKUP_INTERVAL ساعت"
}

# بررسی آرگومان‌های خط فرمان
if [[ "$1" == "--run-backup" ]]; then
    # بارگذاری تنظیمات
    if ! load_config; then
        echo "خطا: فایل تنظیمات یافت نشد!"
        exit 1
    fi
    
    # اجرای بکاپ
    create_backup
    exit 0
fi

# شروع اسکریپت اصلی
echo "اسکریپت تنظیم بکاپ خودکار Marzban"

# بررسی و بارگذاری تنظیمات یا دریافت از کاربر
if ! load_config; then
    get_user_input
    load_config
fi

# تنظیم کرون جاب
setup_cron

# اجرای بکاپ اولیه
create_backup

echo "تنظیمات با موفقیت انجام شد. بکاپ اولیه ارسال شد."
echo "برای مشاهده لاگ‌ها، فایل $LOG_FILE را بررسی کنید."
