import numpy as np
import matplotlib.pyplot as plt

# Constants from the script
TEMP_MIN = 50  # °C
TEMP_MAX = 75  # °C
FAN_MIN = 20   # PWM
FAN_MAX = 255  # PWM

# Generate temperature points
temps = np.linspace(TEMP_MIN, TEMP_MAX, 100)

# Calculate fan speeds using the cubic formula
def calculate_fan_speed(temp):
    temp_diff = temp - TEMP_MIN
    range_temp = TEMP_MAX - TEMP_MIN
    fan_range = FAN_MAX - FAN_MIN
    
    # Cubic interpolation
    temp_factor = temp_diff ** 3
    range_factor = range_temp ** 3
    speed = FAN_MIN + (temp_factor * fan_range / range_factor)
    
    # Ensure we don't exceed FAN_MAX
    return min(speed, FAN_MAX)

# Calculate fan speeds and convert to percentage
fan_speeds = [calculate_fan_speed(t) * 100 / 255 for t in temps]

# Create the plot
plt.figure(figsize=(10, 6))
plt.plot(temps, fan_speeds, 'b-', linewidth=2)
plt.grid(True, linestyle='--', alpha=0.7)
plt.xlabel('Temperature (°C)')
plt.ylabel('Fan Speed (%)')
plt.title('Fan Speed vs Temperature (Cubic Interpolation)')

# Add some reference points
plt.axhline(y=100, color='r', linestyle='--', alpha=0.3)
plt.axvline(x=TEMP_MIN, color='g', linestyle='--', alpha=0.3)
plt.axvline(x=TEMP_MAX, color='g', linestyle='--', alpha=0.3)

# Add annotations
plt.annotate(f'Min Temp ({TEMP_MIN}°C)', 
            xy=(TEMP_MIN, 0), 
            xytext=(TEMP_MIN-2, 10),
            arrowprops=dict(facecolor='black', shrink=0.05))
plt.annotate(f'Max Temp ({TEMP_MAX}°C)', 
            xy=(TEMP_MAX, 100), 
            xytext=(TEMP_MAX-2, 90),
            arrowprops=dict(facecolor='black', shrink=0.05))

plt.savefig('fan_curve.png')
plt.close() 