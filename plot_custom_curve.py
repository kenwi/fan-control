#!/usr/bin/env python3

import pandas as pd
import matplotlib.pyplot as plt
import argparse
from pathlib import Path
import sys

def plot_temperature_data(csv_file, smooth_window=None):
    try:
        # Read the CSV file
        df = pd.read_csv(csv_file)
        
        # Convert timestamp to datetime
        df['Timestamp'] = pd.to_datetime(df['Timestamp'])
        
        # Apply smoothing if window size is specified
        if smooth_window:
            # Calculate rolling average for each column
            df['CPU Temp (°C)'] = df['CPU Temp (°C)'].rolling(window=smooth_window, center=True).mean()
            df['System Temp (°C)'] = df['System Temp (°C)'].rolling(window=smooth_window, center=True).mean()
            df['PECI Temp (°C)'] = df['PECI Temp (°C)'].rolling(window=smooth_window, center=True).mean()
            df['Fan Speed (%)'] = df['Fan Speed (%)'].rolling(window=smooth_window, center=True).mean()
            df['CPU Usage (%)'] = df['CPU Usage (%)'].rolling(window=smooth_window, center=True).mean()
            
            # Drop NaN values that result from rolling average
            df = df.dropna()
        
        # Create the plot and axes
        fig, ax1 = plt.subplots(figsize=(15, 8))
        
        # Calculate statistics for legend
        cpu_stats = f"CPU Temp: {df['CPU Temp (°C)'].mean():.1f}°C avg, {df['CPU Temp (°C)'].max():.1f}°C max"
        sys_stats = f"System Temp: {df['System Temp (°C)'].mean():.1f}°C avg, {df['System Temp (°C)'].max():.1f}°C max"
        peci_stats = f"PECI Temp: {df['PECI Temp (°C)'].mean():.1f}°C avg, {df['PECI Temp (°C)'].max():.1f}°C max"
        fan_stats = f"Fan Speed: {df['Fan Speed (%)'].mean():.1f}% avg, {df['Fan Speed (%)'].max():.1f}% max"
        cpu_load_stats = f"CPU Load: {df['CPU Usage (%)'].mean():.1f}% avg, {df['CPU Usage (%)'].max():.1f}% max"
        
        # Plot temperatures and keep handles for legend
        cpu_line, = ax1.plot(df['Timestamp'], df['CPU Temp (°C)'], label=cpu_stats, color='red')
        sys_line, = ax1.plot(df['Timestamp'], df['System Temp (°C)'], label=sys_stats, color='orange')
        peci_line, = ax1.plot(df['Timestamp'], df['PECI Temp (°C)'], label=peci_stats, color='green')
        
        # Plot fan speed and CPU load on secondary y-axis and keep handles for legend
        ax2 = ax1.twinx()
        fan_line, = ax2.plot(df['Timestamp'], df['Fan Speed (%)'], label=fan_stats, color='blue', linestyle='--')
        cpu_load_line, = ax2.plot(df['Timestamp'], df['CPU Usage (%)'], label=cpu_load_stats, color='purple', linestyle=':')
        
        # Customize the plot
        title = 'Temperature, Fan Speed, and CPU Load Over Time'
        if smooth_window:
            title += f' (Smoothed, Window={smooth_window})'
        plt.title(title, pad=20)
        ax1.set_xlabel('Time')
        ax1.set_ylabel('Temperature (°C)')
        ax2.set_ylabel('Fan Speed / CPU Load (%)')
        
        # Add grid
        ax1.grid(True, linestyle='--', alpha=0.7)
        
        # Add a single combined legend with all lines
        lines = [cpu_line, sys_line, peci_line, fan_line, cpu_load_line]
        labels = [cpu_stats, sys_stats, peci_stats, fan_stats, cpu_load_stats]
        legend = ax1.legend(lines, labels, loc='upper left', bbox_to_anchor=(0.01, 0.99), framealpha=0.9, fontsize=9)
        legend.set_title('Measurements', prop={'size': 10, 'weight': 'bold'})
        
        # Rotate x-axis labels for better readability
        fig.autofmt_xdate()
        
        # Adjust layout to prevent label cutoff
        plt.tight_layout()
        
        # Generate output filename
        output_file = Path(csv_file).stem
        if smooth_window:
            output_file += f'_smooth{smooth_window}'
        output_file += '.png'
        
        # Save the plot
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Plot saved as: {output_file}")
        
    except FileNotFoundError:
        print(f"Error: File '{csv_file}' not found.")
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print(f"Error: File '{csv_file}' is empty.")
        sys.exit(1)
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Plot temperature and fan speed data from CSV files.')
    parser.add_argument('csv_file', help='Path to the CSV file containing temperature and fan speed data')
    parser.add_argument('--smooth', type=int, help='Window size for smoothing (number of data points to average)')
    args = parser.parse_args()
    
    plot_temperature_data(args.csv_file, args.smooth)

if __name__ == '__main__':
    main() 