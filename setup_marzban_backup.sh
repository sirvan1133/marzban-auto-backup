#!/bin/bash

CONFIG_FILE="$HOME/.marzban_backup_config"
BACKUP_SCRIPT="$HOME/marzban_backup.sh"

install_dependencies() {
  echo "🔧 در حال نصب پیش‌نیازها..."
  sudo apt update -y
  sudo apt install -y curl cron tar bash
}

ask_config() {
  echo "🔐 توکن ربات تلگرام را وارد کنید:"
  read -r TELEGRAM_TOKEN
  echo "💬 آیدی عددی تلگرام خود را وارد کنید:"
  read -r TELEGRAM_CHAT_ID
  echo "⏰ هر چند ساعت یک‌بار می‌خواهید بکاپ ارسال شود؟ (مثال: 6)"
  read -r INTERVAL_HOURS

  cat > "$CONFIG_FILE" <<EOF
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
INTERVAL_HOURS="$INTERVAL_HOURS"
EOF
  echo "✅ تنظیمات ذخیره شدند."
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" || -z "$INTERVAL_HOURS" ]]; then
      echo "⚠️ فایل تنظیمات ناقص است. لطفاً دوباره وارد کنید."
      ask_config
    fi
  else
    ask_config
  fi
}

create_backup_script() {
  cat > "$BACKUP_SCRIPT" <<'EOF'
#!/bin/bash
source "$HOME/.marzban_backup_config"

BACKUP_PATHS=("/var/lib/marzban" "/op/marzban")
BACKUP_FILE="/tmp/marzban_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"

tar -czf "$BACKUP_FILE" "${BACKUP_PATHS[@]}" 2>/dev/null

if [[ $? -ne 0 ]]; then
  echo "❌ خطا در ساخت بکاپ!"
  exit 1
fi

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
-F chat_id="$TELEGRAM_CHAT_ID" \
-F document=@"$BACKUP_FILE" \
-F caption="📦 بکاپ اتومات مارزبان - $(date +'%Y/%m/%d %H:%M:%S')"

rm -f "$BACKUP_FILE"
EOF

  chmod +x "$BACKUP_SCRIPT"
  echo "✅ اسکریپت بکاپ ساخته شد: $BACKUP_SCRIPT"
}

setup_cronjob() {
  CRON_EXPR="0 */$INTERVAL_HOURS * * *"
  CRON_LINE="$CRON_EXPR $BACKUP_SCRIPT >/dev/null 2>&1"

  crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" > /tmp/cron.tmp || true
  echo "$CRON_LINE" >> /tmp/cron.tmp
  crontab /tmp/cron.tmp
  rm -f /tmp/cron.tmp

  echo "📆 کرون‌جاب ثبت شد. هر $INTERVAL_HOURS ساعت یک‌بار اجرا می‌شود."
}

run_once_now() {
  echo "🚀 ارسال اولین بکاپ..."
  "$BACKUP_SCRIPT"
}

# اجرای کل فرآیند
install_dependencies
load_config
create_backup_script
run_once_now
setup_cronjob

echo "🎉 نصب و تنظیم با موفقیت انجام شد!"
