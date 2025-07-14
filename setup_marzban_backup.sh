#!/bin/bash

CONFIG_FILE="$HOME/.marzban_backup_config"
BACKUP_SCRIPT="$HOME/marzban_backup.sh"

# Install necessary packages (curl, tar, cron)
install_dependencies() {
  echo "🔧 Installing required packages..."
  sudo apt update -y
  sudo apt install -y curl cron bash zip
}

# Ask user for Telegram bot token, chat ID, backup interval, container name, and db credentials
ask_config() {
  echo "Enter your Telegram Bot Token:"
  read -r TELEGRAM_TOKEN

  echo "Enter your Telegram Numeric Chat ID:"
  read -r TELEGRAM_CHAT_ID

  echo "How often should the backup run? (e.g., every how many hours):"
  read -r INTERVAL_HOURS

  echo "Enter the Docker container name running your database (e.g. marzban-mysql-1):"
  read -r CONTAINER_NAME

  echo "Enter the MySQL root username inside the container (usually root):"
  read -r DB_USER

  echo "Enter the MySQL root password inside the container:"
  read -r DB_PASSWORD

  # Save config to file
  cat > "$CONFIG_FILE" <<EOF
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
INTERVAL_HOURS="$INTERVAL_HOURS"
CONTAINER_NAME="$CONTAINER_NAME"
DB_USER="$DB_USER"
DB_PASSWORD="$DB_PASSWORD"
EOF

  echo "✅ Config saved successfully."
}

# Load config or ask if not available
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" || -z "$INTERVAL_HOURS" || -z "$CONTAINER_NAME" || -z "$DB_USER" || -z "$DB_PASSWORD" ]]; then
      echo "⚠️ Config is incomplete. Re-entering configuration..."
      ask_config
    fi
  else
    ask_config
  fi
}

# Create the backup script that will be run by cron
create_backup_script() {
  cat > "$BACKUP_SCRIPT" <<EOF
#!/bin/bash
source "$CONFIG_FILE"

BACKUP_FILE="/tmp/marzban_db_backup_\$(date +'%Y%m%d_%H%M%S').sql"

# Run mysqldump inside the Docker container and save backup to host
docker exec \$CONTAINER_NAME /usr/bin/mysqldump -u \$DB_USER -p"\$DB_PASSWORD" --all-databases > "\$BACKUP_FILE"

if [[ \$? -ne 0 ]]; then
  echo "❌ Backup failed!"
  exit 1
fi

# Compress the backup to reduce size
zip "\${BACKUP_FILE}.zip" "\$BACKUP_FILE"
rm -f "\$BACKUP_FILE"

# Send the compressed backup to Telegram
curl -s -X POST "https://api.telegram.org/bot\$TELEGRAM_TOKEN/sendDocument" \\
-F chat_id="\$TELEGRAM_CHAT_ID" \\
-F document=@"\${BACKUP_FILE}.zip" \\
-F caption="📦 Marzban DB Backup - \$(date +'%Y/%m/%d %H:%M:%S')"

# Clean up
rm -f "\${BACKUP_FILE}.zip"
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
