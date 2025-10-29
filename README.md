## SwitchBot API Client (CSV Exporter & Logger)

Small, dependency‑light Python client for the SwitchBot Cloud API. It can:

- Export all devices (and their current status) to a CSV file
- Continuously poll and append device statuses to a CSV on a schedule
- Run locally on Windows/macOS/Linux or as a systemd service on Ubuntu/EC2

### Features

- **List devices**: Discover devices and infrared remotes linked to your account
- **Get status**: Fetch current status for a single device
- **Export to CSV**: One‑shot CSV including device metadata + status columns
- **Log to CSV**: Append timestamped readings every N seconds (default: 300)
- **Timezone control**: Choose `local` or `utc` for the main `timestamp` column; both `timestamp_utc` and `timestamp_local` are always recorded

### Requirements

- Python 3.8+
- `pip` available on your system

Install Python dependencies:

```bash
pip install -r requirements.txt
```

### Credentials

You must set two environment variables with your SwitchBot Cloud credentials (from the SwitchBot app, v6.14+):

- `SWITCHBOT_TOKEN`
- `SWITCHBOT_SECRET`

On Windows PowerShell:

```powershell
$env:SWITCHBOT_TOKEN = "<OPEN_TOKEN>"
$env:SWITCHBOT_SECRET = "<SECRET_KEY>"
```

On Bash (macOS/Linux):

```bash
export SWITCHBOT_TOKEN="<OPEN_TOKEN>"
export SWITCHBOT_SECRET="<SECRET_KEY>"
```

The client will fail fast if these are not set.

### Quick Start (Windows PowerShell)

1) Create and activate a virtual environment (recommended):

```powershell
python -m venv .venv
./.venv/Scripts/Activate.ps1
```

2) Install dependencies:

```powershell
pip install -r requirements.txt
```

3) Set your credentials (see above), then run commands:

```powershell
# List devices
python .\switchbot_client.py devices

# Get status for one device
python .\switchbot_client.py status --device-id "<DEVICE_ID>"

# Get status for all devices
python .\switchbot_client.py status-all

# Export all devices + statuses to a CSV
python .\switchbot_client.py export-csv --out devices.csv

# Continuously log statuses to CSV every 5 minutes
python .\switchbot_client.py log-csv --out timeseries.csv --interval-seconds 300

# Use UTC for the main timestamp column
python .\switchbot_client.py log-csv --out timeseries.csv --interval-seconds 300 --timezone utc

# Start a NEW CSV every run (choose a different filename)
python .\switchbot_client.py log-csv --out timeseries_new.csv --interval-seconds 300
```

To exclude infrared remotes on export/logging, add `--skip-infrared`.

### CSV Columns and Timestamps

- CSV rows include flattened device metadata under `device.*` and status fields under `status.*`.
- `log-csv` adds three timestamp columns to each row:
  - `timestamp_utc`: ISO‑8601, always UTC (e.g., 2025-01-01T00:00:00.000Z)
  - `timestamp_local`: ISO‑8601, your local timezone (e.g., 2025-01-01T00:00:00-05:00)
  - `timestamp`: an alias that equals `timestamp_utc` when `--timezone utc`, otherwise `timestamp_local`
- If you want the header row to include any newly added columns, start with an empty or new destination CSV file.

### Command Reference

```text
python switchbot_client.py devices
python switchbot_client.py status --device-id <DEVICE_ID>
python switchbot_client.py status-all
python switchbot_client.py export-csv --out <PATH_TO_CSV> [--skip-infrared]
python switchbot_client.py log-csv --out <PATH_TO_CSV> --interval-seconds 300 [--timezone local|utc] [--skip-infrared]
```

See `commads.md` for additional examples and notes.

### Running on Linux/macOS

Use your shell’s activation steps for virtualenvs, then the same commands apply. Example:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export SWITCHBOT_TOKEN="<OPEN_TOKEN>"
export SWITCHBOT_SECRET="<SECRET_KEY>"
python3 ./switchbot_client.py devices
```

### Automated EC2 (Ubuntu) Deployment

This repo includes automation to deploy a systemd service that runs `log-csv` on a schedule.

Option 1 — From your Windows machine (PowerShell), run the helper script:

```powershell
./scripts/deploy_ec2.ps1 -PemPath .\YOUR_KEY.pem -RemoteHost <EC2_PUBLIC_IP> -User ubuntu `
  -Token "<OPEN_TOKEN>" -Secret "<SECRET_KEY>" -Timezone local -OutPath /opt/switchbot-api/timeseries.csv
```

Option 2 — SSH to EC2 and run the setup script directly:

```bash
sudo /opt/switchbot-api/scripts/setup_ec2_switchbot.sh \
  --token "<OPEN_TOKEN>" \
  --secret "<SECRET_KEY>" \
  --out /opt/switchbot-api/timeseries.csv \
  --timezone local \
  --interval-seconds 300
```

Helpful operations on EC2:

```bash
# Follow logs
sudo journalctl -u switchbot-logger.service -f

# Check CSV last modified + last rows
sudo ls -l --time-style=full-iso /opt/switchbot-api/timeseries.csv
sudo tail -n 5 /opt/switchbot-api/timeseries.csv
```

Download the CSV back to your Windows machine:

```powershell
scp -i ".\YOUR_KEY.pem" ubuntu@<EC2_PUBLIC_IP>:/opt/switchbot-api/timeseries.csv .\timeseries.csv
```

### Configuration Notes

- Base URL and API version can be overridden via env vars: `SWITCHBOT_BASE_URL` and `SWITCHBOT_API_VERSION` (defaults: `https://api.switch-bot.com` and `v1.1`).
- Credentials are read at runtime by `auth.py` and added as signed headers per SwitchBot API requirements.
- Network timeouts are set to 15s per request.

### Troubleshooting

- "Missing environment variable": Ensure `SWITCHBOT_TOKEN` and `SWITCHBOT_SECRET` are set in the same shell session.
- CSV headers missing expected columns: Start with an empty/new CSV so the header row includes newly discovered keys.
- Service doesn’t start on EC2: Check `journalctl -u switchbot-logger.service -n 50 --no-pager` for errors. Verify Python venv exists under `/opt/switchbot-api/.venv`.
- Windows venv copied to Linux: The setup script will recreate an incompatible venv layout automatically.

### Project Structure

```text
switchbot-api/
  auth.py                 # Builds signed headers from env vars
  switchbot_client.py     # CLI commands: devices, status, status-all, export-csv, log-csv
  commads.md              # Additional command examples and EC2 notes
  scripts/
    deploy_ec2.ps1        # Push repo to EC2 and run setup remotely
    setup_ec2_switchbot.sh# Systemd unit creation + venv install on Ubuntu
  requirements.txt        # Python dependencies
```

### Security

- Never commit your real `SWITCHBOT_TOKEN` or `SWITCHBOT_SECRET` to version control.
- Avoid pasting credentials into shared screenshots or documents.
- Prefer environment variables or a secure secret store.

### License

MIT (see `LICENSE` if present); otherwise treat as MIT for personal use.



