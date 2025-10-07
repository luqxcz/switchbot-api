# open token
token = 'd341a485a42ca8808cc950e532108897cbd06b1531482c71908990ae8eaddef99aa1cd33393a740e6dbeef86907b0585' # copy and paste from the SwitchBot app V6.14 or later
# secret key
secret = '89b8fcbf5eb848e221b9c1e32aa26be9' # copy and paste from the SwitchBot app V6.14 or later


Quick setup (PowerShell on Windows)
Create and activate a venv (recommended):
1. python -m venv .venv
2. .\.venv\Scripts\Activate.ps1

Install deps:
pip install -r requirements.txt

Set your credentials in this terminal:
$env:SWITCHBOT_TOKEN = "YOUR_OPEN_TOKEN"
$env:SWITCHBOT_SECRET = "YOUR_SECRET"


Run Commands
List devices: python .\switchbot_client.py devices
Get status: python .\switchbot_client.py status --device-id "<DEVICE_ID>"
Get all statuses: python .\switchbot_client.py status-all
Export all devices+statuses to CSV: python .\switchbot_client.py export-csv --out devices.csv
Continuously log statuses to CSV: python .\switchbot_client.py log-csv --out timeseries.csv --interval-seconds 300
Use UTC timestamps: python .\switchbot_client.py log-csv --out timeseries.csv --interval-seconds 300 --timezone utc
Log to a NEW CSV every 5 minutes: python .\switchbot_client.py log-csv --out timeseries_new.csv --interval-seconds 300

Notes on timestamps
- New columns added when logging with `log-csv`:
  - `timestamp_utc`: ISO-8601 in UTC (e.g., 2025-01-01T00:00:00.000Z)
  - `timestamp_local`: ISO-8601 in your local timezone (e.g., 2025-01-01T00:00:00-05:00)
- The existing `timestamp` column remains as a convenience alias and respects `--timezone`:
  - If `--timezone utc`, `timestamp` == `timestamp_utc`
  - If `--timezone local` (default), `timestamp` == `timestamp_local`
- To ensure these new headers appear, start writing to a new CSV or make sure the destination CSV is empty so the header row includes the new columns.
