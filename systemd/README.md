# Systemd Service Files for Milton Web Server

This directory contains systemd service files for running the Milton web server
as a systemd service.

## Files

- **milton-user.service** - User service file (runs as current user)
- **milton.service** - System service file template (runs as system service)

## User Service Setup (Recommended for Single-User Systems)

User services run under your user account and don't require sudo privileges.

### Installation

1. Create the systemd user service directory if it doesn't exist:
   ```bash
   mkdir -p ~/.config/systemd/user
   ```

2. Copy the user service file:
   ```bash
   cp systemd/milton-user.service ~/.config/systemd/user/
   ```

3. Edit the service file to match your installation:
   ```bash
   nano ~/.config/systemd/user/milton-user.service
   ```
   
   Update the following:
   - `Environment="MILTON_BASE=..."` - Set to your Milton installation base directory
     - User installation: `~/.local/milton` or `$HOME/.local/milton`
     - System installation: `/opt/milton` or `/usr`
   - `Environment="PATH=..."` - Ensure `milton` command is in PATH
   - `WorkingDirectory` - Set to your Milton configuration directory (typically `~/.config/milton`)
   - `ExecStart` - Optionally add `-l http://*:PORT` to specify a different port

4. Reload systemd and enable the service:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable milton-user.service
   ```

5. Start the service:
   ```bash
   systemctl --user start milton-user.service
   ```

6. Check the status:
   ```bash
   systemctl --user status milton-user.service
   ```

7. View logs:
   ```bash
   journalctl --user -u milton-user.service -f
   ```

### Enabling User Service at Login

To ensure the service starts automatically when you log in:

```bash
loginctl enable-linger $USER
```

This enables user services to run even when you're not logged in.

## System Service Setup (For Multi-User or Production Systems)

System services run as a system service and require sudo privileges to set up.

### Installation

1. Copy the system service file to the systemd directory:
   ```bash
   sudo cp systemd/milton.service /etc/systemd/system/
   ```

2. Edit the service file to match your installation:
   ```bash
   sudo nano /etc/systemd/system/milton.service
   ```
   
   Update the following:
   - `Environment="MILTON_BASE=..."` - Set to your Milton installation base directory
     - System installation: `/opt/milton` or `/usr`
   - `WorkingDirectory` - Set to your Milton configuration directory
     - System-wide: `/etc/milton`
     - User-specific: `/home/<username>/.config/milton`
   - `User=` and `Group=` - Set to the user account that should run the service
     - This user must have appropriate permissions for configuration files and hardware access
   - `ExecStart` - Optionally add `-l http://*:PORT` to specify a different port

3. Reload systemd and enable the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable milton.service
   ```

4. Start the service:
   ```bash
   sudo systemctl start milton.service
   ```

5. Check the status:
   ```bash
   sudo systemctl status milton.service
   ```

6. View logs:
   ```bash
   sudo journalctl -u milton.service -f
   ```

## Managing the Service

### User Service

- Start: `systemctl --user start milton-user.service`
- Stop: `systemctl --user stop milton-user.service`
- Restart: `systemctl --user restart milton-user.service`
- Status: `systemctl --user status milton-user.service`
- Disable: `systemctl --user disable milton-user.service`
- Enable: `systemctl --user enable milton-user.service`
- Logs: `journalctl --user -u milton-user.service -f`

### System Service

- Start: `sudo systemctl start milton.service`
- Stop: `sudo systemctl stop milton.service`
- Restart: `sudo systemctl restart milton.service`
- Status: `sudo systemctl status milton.service`
- Disable: `sudo systemctl disable milton.service`
- Enable: `sudo systemctl enable milton.service`
- Logs: `sudo journalctl -u milton.service -f`

## Custom Port

To run Milton on a port other than the default (3000), modify the `ExecStart` line:

```ini
ExecStart=/usr/bin/env milton daemon -l http://*:4000
```

Replace `4000` with your desired port number.

## Troubleshooting

### Service fails to start

1. Check the service status: `systemctl --user status milton-user.service` or `sudo systemctl status milton.service`
2. Check the logs: `journalctl --user -u milton-user.service` or `sudo journalctl -u milton.service`
3. Verify `milton` command is in PATH: `which milton`
4. Verify MILTON_BASE is set correctly
5. Verify the configuration directory exists and is accessible
6. Test running the command manually: `milton daemon`

### Permission issues

- Ensure the user specified in `User=` has read access to configuration files
- Ensure the user has appropriate permissions for hardware access (serial ports, USB devices)
- You may need to add the user to groups like `dialout` or `tty` for serial port access:
  ```bash
  sudo usermod -a -G dialout,tty USERNAME
  ```

### Network/Port issues

- Check if the port is already in use: `netstat -tlnp | grep :3000` or `ss -tlnp | grep :3000`
- Ensure firewall allows connections to the port
- For system services, check SELinux/AppArmor settings if applicable

## Notes

- The service will automatically restart if it crashes (configured with `Restart=on-failure`)
- Logs are sent to the systemd journal
- User services don't start automatically on boot unless `loginctl enable-linger` is used
- System services start automatically on boot when enabled
- The service type is `simple` which means systemd considers the service started once the process has started

