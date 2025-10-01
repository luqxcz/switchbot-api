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