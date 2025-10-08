#!/usr/bin/env bash

set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "This script must be run with sudo/root." >&2
  exit 1
fi

TOKEN=""
SECRET=""
REPO_DIR="/opt/switchbot-api"
SERVICE_USER="ubuntu"
OUT_PATH="/opt/switchbot-api/timeseries.csv"
TIMEZONE="local"
INTERVAL_SECONDS="300"
SKIP_INFRARED="false"

print_usage() {
  cat <<USAGE
Usage: sudo ./setup_ec2_switchbot.sh \\
  --token <OPEN_TOKEN> \\
  --secret <SECRET_KEY> \\
  [--repo-dir /opt/switchbot-api] \\
  [--user ubuntu] \\
  [--out /opt/switchbot-api/timeseries.csv] \\
  [--timezone local|utc] \\
  [--interval-seconds 300] \\
  [--skip-infrared]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)
      TOKEN="$2"; shift 2 ;;
    --secret)
      SECRET="$2"; shift 2 ;;
    --repo-dir)
      REPO_DIR="$2"; shift 2 ;;
    --user)
      SERVICE_USER="$2"; shift 2 ;;
    --out)
      OUT_PATH="$2"; shift 2 ;;
    --timezone)
      TIMEZONE="$2"; shift 2 ;;
    --interval-seconds)
      INTERVAL_SECONDS="$2"; shift 2 ;;
    --skip-infrared)
      SKIP_INFRARED="true"; shift 1 ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage; exit 2 ;;
  esac
done

if [[ -z "$TOKEN" || -z "$SECRET" ]]; then
  echo "--token and --secret are required" >&2
  exit 2
fi

echo "==> Ensuring dependencies (apt, python3, venv)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-venv python3-pip || true
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found after install" >&2
  exit 3
fi

echo "==> Preparing repository at $REPO_DIR"
mkdir -p "$REPO_DIR"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$REPO_DIR"

if [[ -f "$REPO_DIR/requirements.txt" ]]; then
  echo "==> Creating venv and installing requirements"
  # If a Windows venv was copied (Scripts/Lib) or bin/python is missing, remove and recreate
  if [[ -d "$REPO_DIR/.venv" && ! -x "$REPO_DIR/.venv/bin/python" ]]; then
    echo "Found incompatible venv layout; removing $REPO_DIR/.venv"
    rm -rf "$REPO_DIR/.venv"
  fi
  if [[ ! -d "$REPO_DIR/.venv" ]]; then
    python3 -m venv "$REPO_DIR/.venv" || true
    if [[ ! -x "$REPO_DIR/.venv/bin/python" ]]; then
      echo "venv creation fallback: installing version-specific venv package"
      apt-get install -y python3.12-venv || true
      python3 -m venv "$REPO_DIR/.venv" || true
    fi
  fi
  if [[ ! -x "$REPO_DIR/.venv/bin/python" ]]; then
    echo "Virtualenv creation failed (missing $REPO_DIR/.venv/bin/python)" >&2
    ls -la "$REPO_DIR/.venv" || true
    which python3 || true
    python3 -V || true
    exit 3
  fi
  "$REPO_DIR/.venv/bin/python" -m pip install --upgrade pip
  "$REPO_DIR/.venv/bin/pip" install -r "$REPO_DIR/requirements.txt"
fi

echo "==> Writing environment file /etc/default/switchbot"
cat > /etc/default/switchbot <<ENVFILE
SWITCHBOT_TOKEN=$TOKEN
SWITCHBOT_SECRET=$SECRET
ENVFILE
chmod 600 /etc/default/switchbot

echo "==> Creating output directory and permissions"
mkdir -p "$(dirname "$OUT_PATH")"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$(dirname "$OUT_PATH")"

UNIT_FILE="/etc/systemd/system/switchbot-logger.service"
echo "==> Writing systemd unit $UNIT_FILE"
EXTRA_FLAGS=""
if [[ "$TIMEZONE" == "utc" || "$TIMEZONE" == "local" ]]; then
  EXTRA_FLAGS+=" --timezone $TIMEZONE"
fi
if [[ "$SKIP_INFRARED" == "true" ]]; then
  EXTRA_FLAGS+=" --skip-infrared"
fi

cat > "$UNIT_FILE" <<UNIT
[Unit]
Description=SwitchBot CSV Logger (5-minute polling)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$REPO_DIR
EnvironmentFile=/etc/default/switchbot
ExecStart=$REPO_DIR/.venv/bin/python $REPO_DIR/switchbot_client.py log-csv --out $OUT_PATH --interval-seconds $INTERVAL_SECONDS$EXTRA_FLAGS
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

echo "==> Enabling and starting service"
systemctl daemon-reload
systemctl enable --now switchbot-logger.service
sleep 1
systemctl status switchbot-logger.service --no-pager || true
echo "==> Tail logs with: journalctl -u switchbot-logger.service -f"

echo "Deployment complete."


