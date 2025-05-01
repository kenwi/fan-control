# Fan Control System - Command Reference

This document contains all the commands used in setting up and managing the fan control system.

## Hardware Investigation

### List Hardware Monitoring Devices
```bash
ls -l /sys/class/hwmon/
```
Lists all hardware monitoring devices. Each `hwmon*` directory represents a different hardware monitoring chip.

### Find NCT6798 Device
```bash
for i in /sys/class/hwmon/hwmon*; do echo -n "$i: "; cat $i/name 2>/dev/null; done
```
Lists all hwmon devices with their names. Look for "nct6798" in the output to identify the correct hwmon number.

### Check Available Sensors
```bash
sensors
```
Shows temperature and fan readings from all available sensors. Useful to verify which sensors are being detected.

### List Fan and PWM Files
```bash
ls -l /sys/class/hwmon/hwmon4/fan*_input /sys/class/hwmon/hwmon4/pwm*
```
Lists all fan speed and PWM control files for the NCT6798 device.

## Fan Monitoring

### Check Current Fan Speeds
```bash
echo "Current Fan Speeds:"; for i in {1..7}; do label=$(cat /sys/class/hwmon/hwmon4/fan${i}_label 2>/dev/null); speed=$(cat /sys/class/hwmon/hwmon4/fan${i}_input 2>/dev/null); if [ ! -z "$speed" ]; then if [ ! -z "$label" ]; then echo "Fan $i ($label): $speed RPM"; else echo "Fan $i: $speed RPM"; fi; else echo "Fan $i: N/A"; fi; done
```
Shows the current speed of all fans (1-7). If a fan has a label, it will be shown in parentheses. "N/A" indicates the fan doesn't exist.

Example output:
```
Current Fan Speeds:
Fan 1: 798 RPM
Fan 2: 666 RPM
Fan 3: 0 RPM
Fan 4: 846 RPM
Fan 5: 0 RPM
Fan 6: 0 RPM
Fan 7: 0 RPM
```

### Check Current PWM Values
```bash
echo -e "\nCurrent PWM Values:"; for i in {1..7}; do echo -n "PWM $i: "; cat /sys/class/hwmon/hwmon4/pwm${i} 2>/dev/null || echo "N/A"; done
```
Shows the current PWM values for all fans (1-7).

### Check Temperature Sensors
```bash
echo "Temperature Sensors:"; for i in {1..7}; do echo -n "Temp $i ($(cat /sys/class/hwmon/hwmon4/temp${i}_label 2>/dev/null || echo "Unknown")): "; temp=$(cat /sys/class/hwmon/hwmon4/temp${i}_input 2>/dev/null); if [ ! -z "$temp" ]; then echo "$(echo "scale=1; $temp/1000" | bc)°C"; else echo "N/A"; fi; done
```
Shows the current temperature readings from all sensors, including their labels and values in Celsius. The raw values are in millidegrees Celsius (m°C), so we divide by 1000 to get degrees Celsius.

Example output:
```
Temperature Sensors:
Temp 1 (CPU): 38.0°C
Temp 2 (System): 55.5°C
Temp 3 (PCH): 44.0°C
Temp 4 (VRM): 8.0°C
Temp 5 (CPU Socket): 54.0°C
Temp 6 (Motherboard): 31.0°C
Temp 7 (PCIe): 52.0°C
```

## Service Management

### Check Service Status
```bash
sudo systemctl status fan-control.service
```
Shows the current status of the fan control service, including whether it's running, any recent logs, and its configuration.

### Enable Service
```bash
sudo systemctl enable fan-control.service
```
Configures the service to start automatically on system boot.

### Start Service
```bash
sudo systemctl start fan-control.service
```
Starts the fan control service immediately.

### Reload Systemd
```bash
sudo systemctl daemon-reload
```
Reloads the systemd configuration after making changes to service files.

## Log Monitoring

### View All Service Logs
```bash
journalctl -u fan-control.service
```
Displays all logs from the fan control service.

### Follow Logs in Real-time
```bash
journalctl -u fan-control.service -f
```
Shows logs as they are generated, useful for real-time monitoring.

### View Recent Logs
```bash
journalctl -u fan-control.service --since "1 hour ago"
```
Shows logs from the last hour. You can adjust the time period (e.g., "30 min ago", "2 hours ago").

### View Logs with Timestamps
```bash
journalctl -u fan-control.service -o short-precise
```
Displays logs with precise timestamps.

## Installation Commands

### Copy Script
```bash
sudo cp fan-control.sh /usr/local/bin/
```
Copies the fan control script to the system's binary directory.

### Make Script Executable
```bash
sudo chmod +x /usr/local/bin/fan-control.sh
```
Sets the execute permission on the fan control script.

### Create Service File
```bash
sudo nano /etc/systemd/system/fan-control.service
```
Opens a text editor to create the systemd service file.

## Python Dependencies

### Install Required Packages
```bash
pip3 install numpy matplotlib
```
Installs the Python packages needed for generating the fan curve visualization.

### Generate Custom Curve
```bash
python3 plot_custom_curve.py
```
Runs the Python script to generate a visualization of the fan curve with custom settings.

## System Information

### Check Service List
```bash
systemctl list-units --type=service | grep -i fan
```
Lists all services with "fan" in their name.

### Check Kernel Modules
```bash
lsmod | grep -i fan
```
Lists any kernel modules related to fan control.

## Notes
- All commands that modify system settings require `sudo` privileges
- The service file should be created with the correct permissions and content
- Log monitoring commands can be combined with additional filters for more specific output
- Python visualization commands require the script to be in the current directory or the full path to be specified
- The hwmon number (e.g., hwmon4) may vary between systems. Use the hardware investigation commands to find the correct number for your system
- Some fan and temperature sensor numbers may not exist on your system. The commands will show "N/A" for these
- The NCT6798 chip is commonly used in ASUS motherboards, but the hwmon number can vary depending on other hardware in your system. To find the correct hwmon number:
  1. First, list all hwmon devices and their names:
     ```bash
     for i in /sys/class/hwmon/hwmon*; do echo -n "$i: "; cat $i/name 2>/dev/null; done
     ```
  2. Look for "nct6798" in the output. If you don't see it, try:
     ```bash
     sensors | grep -i nct
     ```
  3. Once you find the correct hwmon number, verify it by checking if it has fan and temperature files:
     ```bash
     ls -l /sys/class/hwmon/hwmonX/fan*_input /sys/class/hwmon/hwmonX/temp*_input
     ```
     (replace X with your hwmon number)
  4. If you have multiple hwmon devices, you can check their capabilities:
     ```bash
     for i in /sys/class/hwmon/hwmon*; do echo "=== $i ==="; ls -l $i/fan*_input $i/temp*_input 2>/dev/null; done
     ```
  5. The correct hwmon device should have both fan and temperature input files, and possibly PWM control files 