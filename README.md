# Open Directory Monitor

`opendirmon.sh` is a script designed to monitor open directories on the web, download their contents, and log relevant metadata such as IP addresses and user agents. It includes robust VPN handling to ensure anonymity and security.

## Features

- **VPN Integration**: Uses PIA (Private Internet Access) VPN to rotate regions and ensure anonymity.
- **Fallback Logic**: Handles cases where `ifconfig.me` returns a 403 by falling back to `piactl` for IP verification.
- **Region Skipping**: Automatically skips regions where both `ifconfig.me` and `piactl` fail to provide a valid VPN IP.
- **Customizable Options**: Supports user-specified `wget` options to override defaults.
- **Duplicate Detection**: Detects and removes duplicate files based on SHA-256 hashes.
- **User-Agent Rotation**: Randomly selects a user agent for each download session.
- **Error Handling**: Cleans up incomplete downloads and retries with a new VPN region.

## Usage

```bash
./opendirmon.sh <URL> [interval_seconds] [wget_options]
```

- `<URL>`: The URL of the open directory to monitor. This may be an IP:PORT combination.
- `[interval_seconds]`: Optional. The interval between checks (default: 300 seconds).
- `[wget_options]`: Optional. Additional `wget` options to customize the download behavior.

## Example

Monitor an open directory with a 5-second interval and custom `wget` options:

```bash
./opendirmon.sh http://example.com/open-directory 5 --reject "*.jpg" --quota=100m
```

Monitor an open directory with a static user agent by overriding the `--user-agent` option:

```bash
./opendirmon.sh http://example.com/open-directory 5 --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
```

## Logs

- **IP Log**: `~/opendirmon/opendir/ip_log.txt`
  - Contains timestamps, VPN IPs, public IPs, and regions used.
- **Hash Log**: `~/opendirmon/opendir/hashes.txt`
  - Tracks SHA-256 hashes of downloaded files to detect duplicates.

## Requirements

- **Dependencies**:
  - `wget`
  - `curl`
  - `piactl` (PIA VPN CLI tool)
- **Environment**:
  - Bash shell
  - Linux or macOS

## License

This project is licensed under the MIT License.
