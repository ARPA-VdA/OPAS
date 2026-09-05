#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import sys
import random
import time
import os
from datetime import datetime, timedelta

# --- Configuration ---
DEFAULT_OUTPUT_FILE = os.path.expanduser("~/px375_data.txt")
DEFAULT_INTERVAL = 60  # seconds between data generation


def generate_hex_status():
    """Generate random 16-byte hex status string."""
    return f"0x{random.randint(0, 0xFFFFFFFFFFFFFFFF):016X}"


def generate_data_record():
    """
    Generate a complete PX375 data record.
    Format: Pump-Begin;Pump-End;MassResetTime;Number-of-Split;Analysis-Id;Alarms;ElemError;Mass;Conc;Al;Si;S;K;Ca;Ti;V;Cr;Mn;Fe;Ni;Cu;Zn;As;Pb
    """
    # Generate timestamps
    now = datetime.now()
    pump_begin = now - timedelta(hours=6)
    pump_end = now
    mass_reset_time = now

    # Format dates as yyyy/MM/dd HH:mm:ss
    date_fmt = "%Y/%m/%d %H:%M:%S"
    pump_begin_str = pump_begin.strftime(date_fmt)
    pump_end_str = pump_end.strftime(date_fmt)
    mass_reset_str = mass_reset_time.strftime(date_fmt)

    # Generate numeric fields
    num_split = random.randint(0, 10)
    analysis_id = random.randint(1000, 9999)
    mass = round(random.uniform(50.0, 150.0), 1)  # ug
    conc = round(random.uniform(5.0, 30.0), 2)    # ug/m3

    # Generate element concentrations (ng/m3)
    al = round(random.uniform(100.0, 500.0), 2)
    si = round(random.uniform(200.0, 600.0), 2)
    s = round(random.uniform(100.0, 400.0), 2)
    k = round(random.uniform(50.0, 300.0), 2)
    ca = round(random.uniform(100.0, 500.0), 2)
    ti = round(random.uniform(10.0, 50.0), 2)
    v = round(random.uniform(1.0, 10.0), 2)
    cr = round(random.uniform(5.0, 20.0), 2)
    mn = round(random.uniform(10.0, 40.0), 2)
    fe = round(random.uniform(200.0, 700.0), 2)
    ni = round(random.uniform(5.0, 20.0), 2)
    cu = round(random.uniform(10.0, 40.0), 2)
    zn = round(random.uniform(50.0, 150.0), 2)
    as_val = round(random.uniform(1.0, 10.0), 2)
    pb = round(random.uniform(5.0, 30.0), 2)

    # Generate status codes (hex)
    alarms = generate_hex_status()
    elem_error = generate_hex_status()

    # Construct record
    record = ";".join([
        pump_begin_str,      # 0
        pump_end_str,        # 1
        mass_reset_str,      # 2
        str(num_split),      # 3
        str(analysis_id),    # 4
        alarms,              # 5
        elem_error,          # 6
        str(mass),           # 7
        str(conc),           # 8
        str(al),             # 9
        str(si),             # 10
        str(s),              # 11
        str(k),              # 12
        str(ca),             # 13
        str(ti),             # 14
        str(v),              # 15
        str(cr),             # 16
        str(mn),             # 17
        str(fe),             # 18
        str(ni),             # 19
        str(cu),             # 20
        str(zn),             # 21
        str(as_val),         # 22
        str(pb)              # 23
    ])

    return record


def write_data_file(filepath):
    """Write generated data to file."""
    try:
        record = generate_data_record()
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(record)
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{now}] Data file written: {filepath}")
        print(f"Record: {record}")
        return True
    except Exception as e:
        print(f"Error writing data file: {e}")
        return False


def continuous_mode(output_file, interval):
    """Run in continuous mode, generating data at regular intervals."""
    print(f"PX375 Data Generator started (interval: {interval}s)")
    print(f"Output file: {output_file}")
    try:
        while True:
            write_data_file(output_file)
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\nShutting down...")


def single_mode(output_file):
    """Generate a single data record and exit."""
    write_data_file(output_file)


def main():
    output_file = DEFAULT_OUTPUT_FILE
    interval = DEFAULT_INTERVAL
    continuous = False

    # Parse arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Usage: px_375.py [options]")
            print("Options:")
            print("  -o, --output FILE    Output file path (default: ~/px375_data.txt)")
            print("  -i, --interval SEC   Interval in seconds (default: 60)")
            print("  -c, --continuous     Run continuously (default: single shot)")
            print("  -h, --help           Show this help message")
            return

        i = 1
        while i < len(sys.argv):
            if sys.argv[i] in ['-o', '--output']:
                if i + 1 < len(sys.argv):
                    output_file = sys.argv[i + 1]
                    i += 2
                else:
                    print("Error: -o requires an argument")
                    return
            elif sys.argv[i] in ['-i', '--interval']:
                if i + 1 < len(sys.argv):
                    try:
                        interval = int(sys.argv[i + 1])
                    except ValueError:
                        print("Error: interval must be an integer")
                        return
                    i += 2
                else:
                    print("Error: -i requires an argument")
                    return
            elif sys.argv[i] in ['-c', '--continuous']:
                continuous = True
                i += 1
            else:
                print(f"Unknown argument: {sys.argv[i]}")
                return

    # Ensure output directory exists
    output_dir = os.path.dirname(output_file)
    if output_dir and not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"Error creating output directory: {e}")
            return

    # Run in appropriate mode
    if continuous:
        continuous_mode(output_file, interval)
    else:
        single_mode(output_file)


if __name__ == '__main__':
    main()
