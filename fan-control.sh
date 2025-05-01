#!/bin/bash

# Fan control script for NCT6798
# This script monitors temperatures and adjusts fan speeds accordingly

# Default configuration
TEMP_MIN=50000   # 50°C - Start increasing fan speed
TEMP_MAX=75000   # 75°C - Maximum temperature before full speed
FAN_MIN=20       # ~8% - Minimum fan speed
FAN_MAX=255      # 100% - Maximum fan speed
CHECK_INTERVAL=5 # 5 seconds
TEMP_HYST=1000   # 1°C hysteresis to prevent frequent speed changes

# Fan paths (only for connected fans)
FAN1_PWM="/sys/class/hwmon/hwmon4/pwm1"
FAN2_PWM="/sys/class/hwmon/hwmon4/pwm2"
FAN4_PWM="/sys/class/hwmon/hwmon4/pwm4"

# PWM mode paths (only for connected fans)
FAN1_MODE="/sys/class/hwmon/hwmon4/pwm1_mode"
FAN2_MODE="/sys/class/hwmon/hwmon4/pwm2_mode"
FAN4_MODE="/sys/class/hwmon/hwmon4/pwm4_mode"

# PWM enable paths (only for connected fans)
FAN1_ENABLE="/sys/class/hwmon/hwmon4/pwm1_enable"
FAN2_ENABLE="/sys/class/hwmon/hwmon4/pwm2_enable"
FAN4_ENABLE="/sys/class/hwmon/hwmon4/pwm4_enable"

# Temperature sensor paths
CPU_TEMP="/sys/class/hwmon/hwmon4/temp2_input"  # CPUTIN
SYS_TEMP="/sys/class/hwmon/hwmon4/temp1_input"  # SYSTIN
PECI_TEMP="/sys/class/hwmon/hwmon4/temp8_input" # PECI Agent 0

# Store last fan speed for hysteresis
LAST_FAN_SPEED=$FAN_MIN

# Store last CPU usage values
LAST_CPU_TOTAL=0
LAST_CPU_IDLE=0

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --fan-speed SPEED    Set manual fan speed (0-100%)"
    echo "  --min-temp TEMP     Set minimum temperature in °C (default: 50)"
    echo "  --max-temp TEMP     Set maximum temperature in °C (default: 75)"
    echo "  --min-speed SPEED   Set minimum fan speed in % (default: 8)"
    echo "  --max-speed SPEED   Set maximum fan speed in % (default: 100)"
    echo "  --interval SECONDS  Set check interval in seconds (default: 5)"
    echo "  --help             Show this help message"
    echo
    echo "Without options, runs in automatic temperature-based control mode."
    exit 1
}

# Function to convert percentage to PWM value (0-255)
percent_to_pwm() {
    local percent=$1
    echo $((percent * 255 / 100))
}

# Function to get temperature in millidegrees
get_temp() {
    local temp_file=$1
    if [ -f "$temp_file" ]; then
        cat "$temp_file"
    else
        echo "0"
    fi
}

# Function to get CPU usage percentage
get_cpu_usage() {
    # Get CPU usage using vmstat command
    local cpu_usage
    # Run vmstat twice with 1 second interval to get accurate reading
    cpu_usage=$(vmstat 1 2 | tail -n1 | awk '{print 100 - $15}')
    
    # Round to nearest integer
    cpu_usage=$(printf "%.0f" "$cpu_usage")
    
    # Ensure the value is between 0 and 100
    if [ "$cpu_usage" -lt 0 ]; then
        cpu_usage=0
    elif [ "$cpu_usage" -gt 100 ]; then
        cpu_usage=100
    fi

    echo "$cpu_usage"
}

# Function to set fan speed
set_fan_speed() {
    local pwm_file=$1
    local speed=$2
    local fan_name=$(basename "$pwm_file")
    if [ -f "$pwm_file" ]; then
        if ! echo "$speed" > "$pwm_file" 2>/dev/null; then
            logger "Fan Control: Failed to set speed for $fan_name (Device busy)"
            return 1
        else
            logger "Fan Control: Set $fan_name to speed $speed"
            return 0
        fi
    else
        logger "Fan Control: $fan_name not found"
        return 1
    fi
}

# Function to set PWM mode to manual
set_pwm_mode() {
    local mode_file=$1
    local fan_name=$(basename "$mode_file" | sed 's/_mode//')
    if [ -f "$mode_file" ]; then
        if ! echo "1" > "$mode_file" 2>/dev/null; then
            logger "Fan Control: Failed to set manual mode for $fan_name (Device busy)"
            return 1
        else
            logger "Fan Control: Set $fan_name to manual mode"
            return 0
        fi
    else
        logger "Fan Control: Mode file for $fan_name not found"
        return 1
    fi
}

# Function to set PWM enable to manual
set_pwm_enable() {
    local enable_file=$1
    local fan_name=$(basename "$enable_file" | sed 's/_enable//')
    if [ -f "$enable_file" ]; then
        if ! echo "1" > "$enable_file" 2>/dev/null; then
            logger "Fan Control: Failed to set manual enable for $fan_name (Device busy)"
            return 1
        else
            logger "Fan Control: Set $fan_name to manual enable"
            return 0
        fi
    else
        logger "Fan Control: Enable file for $fan_name not found"
        return 1
    fi
}

# Function to calculate fan speed based on temperature
calculate_fan_speed() {
    local temp=$1
    local new_speed

    if [ "$temp" -le "$TEMP_MIN" ]; then
        new_speed=$FAN_MIN
    elif [ "$temp" -ge "$TEMP_MAX" ]; then
        new_speed=$FAN_MAX
    else
        # Non-linear interpolation for more aggressive response to temperature increases
        local range=$((TEMP_MAX - TEMP_MIN))
        local fan_range=$((FAN_MAX - FAN_MIN))
        local temp_diff=$((temp - TEMP_MIN))
        # Cube the temperature difference for even more aggressive response
        local temp_factor=$((temp_diff * temp_diff * temp_diff))
        local range_factor=$((range * range * range))
        new_speed=$((FAN_MIN + (temp_factor * fan_range / range_factor)))
        # Ensure we don't exceed FAN_MAX
        if [ "$new_speed" -gt "$FAN_MAX" ]; then
            new_speed=$FAN_MAX
        fi
    fi

    # Apply hysteresis - only change speed if difference is significant
    if [ $((new_speed - LAST_FAN_SPEED)) -gt 5 ] || [ $((LAST_FAN_SPEED - new_speed)) -gt 5 ]; then
        LAST_FAN_SPEED=$new_speed
    else
        new_speed=$LAST_FAN_SPEED
    fi

    echo "$new_speed"
}

# Parse command line arguments
MANUAL_SPEED=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --fan-speed)
            MANUAL_SPEED="$2"
            shift 2
            ;;
        --min-temp)
            TEMP_MIN=$((${2} * 1000))
            shift 2
            ;;
        --max-temp)
            TEMP_MAX=$((${2} * 1000))
            shift 2
            ;;
        --min-speed)
            FAN_MIN=$(percent_to_pwm ${2})
            shift 2
            ;;
        --max-speed)
            FAN_MAX=$(percent_to_pwm ${2})
            shift 2
            ;;
        --interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --help)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Set PWM modes and enables to manual (only for connected fans)
logger "Fan Control: Setting PWM modes and enables to manual"
set_pwm_mode "$FAN1_MODE"
set_pwm_mode "$FAN2_MODE"
set_pwm_mode "$FAN4_MODE"
set_pwm_enable "$FAN1_ENABLE"
set_pwm_enable "$FAN2_ENABLE"
set_pwm_enable "$FAN4_ENABLE"

# If manual speed is set, apply it and exit
if [ ! -z "$MANUAL_SPEED" ]; then
    if ! [[ "$MANUAL_SPEED" =~ ^[0-9]+$ ]] || [ "$MANUAL_SPEED" -lt 0 ] || [ "$MANUAL_SPEED" -gt 100 ]; then
        echo "Error: Fan speed must be between 0% and 100%"
        exit 1
    fi
    PWM_VALUE=$(percent_to_pwm "$MANUAL_SPEED")
    echo "Setting all fans to $MANUAL_SPEED% (PWM: $PWM_VALUE)"
    set_fan_speed "$FAN1_PWM" "$PWM_VALUE"
    set_fan_speed "$FAN2_PWM" "$PWM_VALUE"
    set_fan_speed "$FAN4_PWM" "$PWM_VALUE"
    exit 0
fi

# Main control loop for automatic mode
while true; do
    # Get temperatures
    cpu_temp=$(get_temp "$CPU_TEMP")
    sys_temp=$(get_temp "$SYS_TEMP")
    peci_temp=$(get_temp "$PECI_TEMP")

    # Get CPU usage
    cpu_usage=$(get_cpu_usage)

    # Use the highest temperature
    max_temp=$((cpu_temp > sys_temp ? cpu_temp : sys_temp))
    max_temp=$((max_temp > peci_temp ? max_temp : peci_temp))

    # Calculate fan speeds
    fan_speed=$(calculate_fan_speed "$max_temp")

    # Set fan speeds (only for connected fans)
    set_fan_speed "$FAN1_PWM" "$fan_speed"
    set_fan_speed "$FAN2_PWM" "$fan_speed"
    set_fan_speed "$FAN4_PWM" "$fan_speed"

    # Log temperature, CPU usage, and fan speed
    logger "Fan Control: CPU Temp: $((cpu_temp/1000))°C, System Temp: $((sys_temp/1000))°C, CPU Usage: ${cpu_usage}%, Fan Speed: $((fan_speed*100/255))%"

    # Wait before next check
    sleep "$CHECK_INTERVAL"
done 