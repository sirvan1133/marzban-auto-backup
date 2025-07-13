#!/bin/bash

# Colors
green='\033[0;32m'
red='\033[0;31m'
plain='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${red}❌ Please run as root${plain}"
  exit 1
fi

# Paths
config_file="/etc/marzban_backup.conf"
script_path="/usr/local/bin/send_marzban_backup.sh"

# Ask for user input
read -p "🤖 Enter your Telegram bot token: " bot_token
read -p "🆔 Enter your Telegram numeric ID: " telegram_id
read -p "⏱️ How often (in hours) should the backup be sent? " interval

# Validate interval
if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -eq 0 ]; then
  echo -e "${red}❌ Invalid input. Please enter a numeric value greater than 0.${plain}"
  exit 1
fi

# Save config
echo "BOT_TOKEN=\"$bot_token\"" > "$config_file"
echo "TELEGRAM_ID=\"$telegram_id\"" >> "$config_file"
chmod 600 "$config_file"

# Ensure required commands are installed
for cmd in zip curl; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo -e "${green}📦 Installing $cmd package...${plain}"
    apt update -y && apt install -y $cmd
  fi
done

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

# Make backup script executable
chmod +x "$script_path"

# Run backup script immediately once
echo -e "${green}⏳ Running first backup now...${plain}"
"$script_path"

# Add to crontab (clean old jobs)
(crontab -l 2>/dev/null | grep -v "$script_path"; echo "0 */$interval * * * $script_path") | crontab -

# Final output
echo -e "${green}✅ Configuration saved to: $config_file${plain}"
echo -e "${green}✅ Backup script saved at: $script_path${plain}"
echo -e "${green}✅ Cron job scheduled every $interval hour(s) to send ZIP archive to Telegram.${plain}"
