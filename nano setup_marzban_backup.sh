#!/bin/bash

# Colors
green='\033[0;32m'
red='\033[0;31m'
plain='\033[0m'

# Paths
config_file="/etc/marzban_backup.conf"
script_path="/usr/local/bin/send_marzban_backup.sh"

# Ask for user input
read -p "🤖 Enter your Telegram bot token: " bot_token
read -p "🆔 Enter your Telegram numeric ID: " telegram_id
read -p "⏱️ How often (in hours) should the backup be sent? " interval

# Validate interval
if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
  echo -e "${red}❌ Invalid input. Please enter a numeric value only.${plain}"
  exit 1
fi

# Save config
echo "BOT_TOKEN=\"$bot_token\"" > $config_file
echo "TELEGRAM_ID=\"$telegram_id\"" >> $config_file
chmod 600 $config_file

# Make sure zip is installed
if ! command -v zip >/dev/null 2>&1; then
  echo -e "${green}📦 Installing zip package...${plain}"
  apt update -y && apt install -y zip
fi

# Create the backup script
cat > "$script_path" << 'EOF'
#!/bin/bash

# Load config
source /etc/marzban_backup.conf

# Define backup details
backup_time=$(date +%Y-%m-%d_%H-%M-%S)
backup_file="/tmp/marzban_backup_$backup_time.zip"
dirs=("/var/lib/marzban" "/op/marzban")

# Create ZIP archive
zip -r -q "$backup_file" "${dirs[@]}" 2>/dev/null

# Send ZIP to Telegram
curl -s -F chat_id="$TELEGRAM_ID" -F document=@"$backup_file" \
    "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" > /dev/null

# Remove the backup
rm -f "$backup_file"
EOF

# Make it executable
chmod +x "$script_path"

# Add to crontab (clean old jobs)
(crontab -l 2>/dev/null | grep -v "$script_path"; echo "0 */$interval * * * $script_path") | crontab -

# Final output
echo -e "${green}✅ Configuration saved to: $config_file${plain}"
echo -e "${green}✅ Backup script saved at: $script_path${plain}"
echo -e "${green}✅ Cron job scheduled every $interval hour(s) to send ZIP archive to Telegram.${plain}"
