#!/bin/zsh
# Enhanced backup script for .zshrc and starship.toml with proper cleanup
BACKUP_DIR="/Users/praneeth/Documents/BAK"
TIMESTAMP=$(/bin/date +"%b-%d(%I:%M%p)" | /usr/bin/tr '[:upper:]' '[:lower:]')
/bin/mkdir -p "$BACKUP_DIR"

# Create backup files
BACKUP_FILE_1="zshrc_bak_${TIMESTAMP}"
BACKUP_FILE_2="starship_bak_${TIMESTAMP}"

# Perform backups
/bin/cp /Users/praneeth/.zshrc "$BACKUP_DIR/$BACKUP_FILE_1"
/bin/cp /Users/praneeth/.config/starship.toml "$BACKUP_DIR/$BACKUP_FILE_2"

# Clean up old ZSHRC backups (keep only 2 most recent)
if [ "$(/bin/ls -1 "$BACKUP_DIR"/zshrc_bak_* 2>/dev/null | /usr/bin/wc -l)" -gt 2 ]; then
    /bin/ls -t "$BACKUP_DIR"/zshrc_bak_* | /usr/bin/tail -n +3 | /usr/bin/xargs /bin/rm -f
fi

# Clean up old STARSHIP backups (keep only 2 most recent)
if [ "$(/bin/ls -1 "$BACKUP_DIR"/starship_bak_* 2>/dev/null | /usr/bin/wc -l)" -gt 2 ]; then
    /bin/ls -t "$BACKUP_DIR"/starship_bak_* | /usr/bin/tail -n +3 | /usr/bin/xargs /bin/rm -f
fi

# Log the backup operation
echo "[$(date)] Created backups: $BACKUP_FILE_1 & $BACKUP_FILE_2" >> "$BACKUP_DIR/backup.log"

# Optional: Clean old log entries (keep last 50 lines)
if [ -f "$BACKUP_DIR/backup.log" ]; then
    tail -50 "$BACKUP_DIR/backup.log" > "$BACKUP_DIR/backup.log.tmp" && mv "$BACKUP_DIR/backup.log.tmp" "$BACKUP_DIR/backup.log"
fi
