#!/bin/sh
set -e

CONFIG_DIR="/paperclip/instances/default"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Run onboard if no config exists yet
if [ ! -f "$CONFIG_FILE" ]; then
  echo "No config found, running onboard..."
  mkdir -p "$CONFIG_DIR"
  npx paperclipai onboard --yes 2>/dev/null || true
fi

# Auto-allow any hostname passed via PAPERCLIP_ALLOWED_HOSTNAME env var
if [ -n "$PAPERCLIP_ALLOWED_HOSTNAME" ]; then
  echo "Allowing hostname: $PAPERCLIP_ALLOWED_HOSTNAME"
  npx paperclipai allowed-hostname "$PAPERCLIP_ALLOWED_HOSTNAME" 2>/dev/null || true
fi

# Also try to allow all hostnames by setting exposure to public
if [ -f "$CONFIG_FILE" ]; then
  # Use node to patch the config to allow public exposure
  node -e "
    const fs = require('fs');
    try {
      const cfg = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
      cfg.deployment = cfg.deployment || {};
      cfg.deployment.exposure = 'public';
      cfg.deployment.mode = process.env.PAPERCLIP_DEPLOYMENT_MODE || 'authenticated';
      fs.writeFileSync('$CONFIG_FILE', JSON.stringify(cfg, null, 2));
      console.log('Config patched: exposure=public');
    } catch(e) { console.log('Config patch skipped:', e.message); }
  "
fi

echo "Starting Paperclip server..."
exec node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
