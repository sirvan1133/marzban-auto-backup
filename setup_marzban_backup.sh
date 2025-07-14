#!/bin/bash

CONFIG_FILE="$HOME/.marzban_backup_config"
BACKUP_SCRIPT="$HOME/marzban_backup.sh"

# Install necessary packages (curl, tar, cron)
install_dependencies() {
  echo "🔧 Installing required packages..."
  sudo apt update -y
  sudo apt install -y curl cron tar bash
}

# Ask user for Telegram bot token, chat ID, and backup interval
ask_config() {
  echo "Enter your Telegram Bot Token:"
  read -r TELEGRAM_TOKEN

  echo "Enter your Telegram Numeric Chat ID:"
  read -r TELEGRAM_CHAT_ID

  echo "How often should the backup run? (e.g., every how many hours):"
  read -r INTERVAL_HOURS

  # Save config to file
  cat > "$CONFIG_FILE" <<EOF
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
INTERVAL_HOURS="$INTERVAL_HOURS"
EOF

  echo "✅ Config saved successfully."
}

# Load config or ask if not available
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" || -z "$INTERVAL_HOURS" ]]; then
      echo "⚠️ Config is incomplete. Re-entering configuration..."
      ask_config
    fi
  else
    ask_config
  fi
}

# Create the backup script that will be run by cron
create_backup_script() {
  cat > "$BACKUP_SCRIPT" <<'EOF'
#!/bin/bash
source "$HOME/.marzban_backup_config"

# Directories to backup
BACKUP_PATHS=("/var/lib/marzban" "/op/marzban")

# Output file name
BACKUP_FILE="/tmp/marzban_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"

# Create the backup archive
tar -czf "$BACKUP_FILE" "${BACKUP_PATHS[@]}" 2>/dev/null

# If backup failed
if [[ $? -ne 0 ]]; then
  echo "❌ Backup failed!"
  exit 1
fi

# Send the backup to Telegram
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
-F chat_id="$TELEGRAM_CHAT_ID" \
-F document=@"$BACKUP_FILE" \
-F caption="📦 Marzban auto-backup - $(date +'%Y/%m/%d %H:%M:%S')"

# Clean up
rm -f "$BACKUP_FILE"
EOF

  chmod +x "$BACKUP_SCRIPT"
  echo "✅ Backup script created: $BACKUP_SCRIPT"
}

# Register a cronjob to run backup periodically
setup_cronjob() {
  # Every X hours
  CRON_EXPR="0 */$INTERVAL_HOURS * * *"
  CRON_LINE="$CRON_EXPR $BACKUP_SCRIPT >/dev/null 2>&1"

  # Avoid duplicates
  crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" > /tmp/cron.tmp || true
  echo "$CRON_LINE" >> /tmp/cron.tmp
  crontab /tmp/cron.tmp
  rm -f /tmp/cron.tmp

  echo "📆 Cronjob registered to run every $INTERVAL_HOURS hour(s)."
}

# Run first backup immediately
run_once_now() {
  echo "🚀 Sending first backup now..."
  "$BACKUP_SCRIPT"
}

# Execute the full setup
install_dependencies
load_config
create_backup_script
run_once_now
setup_cronjob

echo "🎉 Setup complete. Automatic Marzban backup is now active!"
