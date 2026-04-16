# Botminter Systemd Service

This directory contains systemd unit files for running botminter as a system service.

## Files

- **`botminter.service`** — Systemd unit file
- **`botminter-start.sh`** — Startup script that syncs git repos before starting botminter

## Installation

### Automated Installation (Recommended)

1. **Edit the environment file with your credentials:**
   ```bash
   cd /home/splat/.botminter/workspaces/splat/team/systemd
   vim botminter.env
   ```
   
   Add your Jira API token (get from https://id.atlassian.com/manage-profile/security/api-tokens):
   ```bash
   JIRA_URL=https://redhat.atlassian.net
   JIRA_USERNAME=your-email@redhat.com
   JIRA_API_TOKEN=your-actual-token-here
   ```

2. **Run the install script:**
   ```bash
   ./install.sh
   ```

   This will:
   - Verify botminter.env exists
   - Copy `botminter-start.sh` to `/usr/local/bin/botminter-start`
   - Copy `botminter.service` to `/etc/systemd/system/`
   - Secure the environment file (chmod 600)
   - Reload systemd

3. **Enable and start:**
   ```bash
   sudo systemctl enable botminter
   sudo systemctl start botminter
   ```

### Manual Installation

1. Copy the startup script to a system location:
   ```bash
   sudo cp botminter-start.sh /usr/local/bin/botminter-start
   sudo chmod +x /usr/local/bin/botminter-start
   sudo chown root:root /usr/local/bin/botminter-start
   ```

2. Copy the service file to systemd directory:
   ```bash
   sudo cp botminter.service /etc/systemd/system/
   ```

3. Reload systemd to recognize the new service:
   ```bash
   sudo systemctl daemon-reload
   ```

4. Enable the service to start on boot:
   ```bash
   sudo systemctl enable botminter
   ```

## Usage

### Start the service
```bash
sudo systemctl start botminter
```

### Stop the service
```bash
sudo systemctl stop botminter
```

### Restart the service
```bash
sudo systemctl restart botminter
```

### Check service status
```bash
sudo systemctl status botminter
```

### View logs
```bash
# Follow logs in real-time
sudo journalctl -u botminter -f

# View recent logs
sudo journalctl -u botminter -n 100

# View logs since boot
sudo journalctl -u botminter -b
```

## Startup Sequence

When the service starts, it:

1. Syncs the team repo:
   ```bash
   cd /home/splat/.botminter/workspaces/splat/team
   git fetch && git rebase origin/main
   ```

2. Syncs the superman-atlas workspace:
   ```bash
   cd /home/splat/.botminter/workspaces/splat/superman-atlas
   git fetch && git rebase origin/main
   ```

3. Starts the botminter daemon (webhook mode):
   ```bash
   bm daemon start
   ```

4. Starts team members:
   ```bash
   bm start
   ```

## Restart Policy

The service automatically restarts on failure with a 10-second delay.

## Environment Variables

The service loads environment variables from `botminter.env`, which contains:
- **Jira credentials** (API token for read-only access)
- **GitHub tokens** (if needed)
- **Other service credentials**

**Security notes:**
- The `botminter.env` file is set to `chmod 600` (owner read/write only)
- **Never commit this file to git** - it's in `.gitignore`
- Rotate API tokens periodically
- Use read-only tokens when possible

To update credentials:
```bash
vim /home/splat/.botminter/workspaces/splat/team/systemd/botminter.env
sudo systemctl restart botminter
```

## Security

The service runs with:
- User: `splat`
- Group: `splat`
- `NoNewPrivileges=true` — prevents privilege escalation
- `PrivateTmp=true` — isolated /tmp directory
- Credentials in secure environment file (not exposed in process list)

## Troubleshooting

### SELinux denials

If you get "Unable to locate executable" errors, check for SELinux denials:
```bash
sudo ausearch -m avc -ts recent | grep -i bm
```

**Fix:** Set the correct SELinux context on the bm binary and startup script:
```bash
sudo chcon -t bin_t /home/splat/.cargo/bin/bm
sudo chcon -t bin_t /usr/local/bin/botminter-start
```

The install script moves the startup script to `/usr/local/bin/` which helps avoid SELinux issues with home directory execution, but the `bm` binary in `~/.cargo/bin/` also needs the correct context.

### Service fails to start

Check the logs:
```bash
sudo journalctl -u botminter -n 50
```

### Git sync fails

The startup script will fail if:
- Git repos have uncommitted changes
- Rebase conflicts occur
- Network is unavailable

To manually fix:
```bash
cd /home/splat/.botminter/workspaces/splat/team
git status
# Resolve any issues, then restart service
```

### Disable auto-start on boot

```bash
sudo systemctl disable botminter
```
