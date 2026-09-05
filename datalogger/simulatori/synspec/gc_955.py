#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import serial
import random
import time
import logging
from datetime import datetime

# --- Configuration ---
SERIAL_PORT = '/dev/ttySC0'
BAUDRATE = 9600
TIMEOUT = 1

# Status Strings
STATUS_DEFAULT = "Status :  1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
STATUS_CALIB   = "Status :  1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0"

# Logging configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
log = logging.getLogger()


def generate_data_string(is_calibrating=False):
    """
    Generates a Synspec GC955 compatible data record.
    Format: N [Tab] Date [Tab] Time [Tab] Conc1 [Tab] Area1 [Tab] ... [Tab] Pressure [Tab] Temp ...
    """
    fields = []

    # 1-3: Header, Date and Time
    fields.append('N')
    fields.append(datetime.now().strftime('%d-%m-%y'))
    fields.append(datetime.now().strftime('%H:%M'))

    # 4-18: Simulated Concentrations and Areas (Benzene, Toluene, etc.)
    # Concentrations (randomized based on mode)
    ranges = [
        (0, 2) if not is_calibrating else (4, 6),    # Comp 1
        (0, 8) if not is_calibrating else (19, 21),  # Comp 2
        (0, 10) if not is_calibrating else (9, 11),  # Comp 3
        (0, 3) if not is_calibrating else (14, 16),  # Comp 4
        (0, 1) if not is_calibrating else (5, 6.5)   # Comp 5
    ]

    for start_val, end_val in ranges:
        val = round(random.uniform(start_val, end_val), 2)
        fields.append(f"{val:.2f}")     # Concentration
        fields.append(str(random.randint(15000, 100000))) # Area (fake)
        fields.append(str(random.randint(150, 500)))      # Height (fake)

    # 19-22: Diagnostics
    pres = round(random.uniform(995, 1013), 2)
    temp = round(random.uniform(20, 25), 2)
    steps = round(random.uniform(2000, 3000), 2)
    corr = round(random.uniform(0, 1), 2)

    fields.append(f"{pres} hPa")
    fields.append(f"{temp} °C")
    fields.append(f"{steps} steps")
    fields.append(f"{corr} corr")
    fields.append("") # Final empty field for trailing tab

    # Join with Tabs and terminate with ASCII 15 (Shift In) as per protocol
    return "\t".join(fields) + chr(15)


def main():
    log.info(f"Starting GC955 Simulator on {SERIAL_PORT} @ {BAUDRATE}")

    try:
        ser = serial.Serial(SERIAL_PORT, BAUDRATE, timeout=TIMEOUT)
    except Exception as e:
        log.error(f"Could not open serial port {SERIAL_PORT}: {e}")
        return

    # internal state
    cached_data = None
    is_calibrating = False
    status_str = STATUS_DEFAULT

    try:
        while True:
            # Read command from serial
            if ser.in_waiting > 0:
                raw_command = ser.readline()
                command = raw_command.decode('latin1', errors='ignore').strip()

                if not command:
                    continue

                now_ts = datetime.now().strftime('%H:%M:%S.%f')[:-3]
                log.info(f"Received @ {now_ts} -> [{command}]")

                # --- Command Logic ---

                # LL: Get Latest Logged Data
                if command.startswith('LL'):
                    now = datetime.now()
                    # Check if it's the start of a new 15-min cycle (0, 15, 30, 45)
                    runs = [0, 15, 30, 45]
                    if now.minute in runs and now.second < 5:
                        log.info(f"New cycle detected. Refreshing data (Cal: {is_calibrating})")
                        cached_data = generate_data_string(is_calibrating)

                    # Fallback if cache is empty
                    if cached_data is None:
                        cached_data = generate_data_string(is_calibrating)

                    log.info(f"Sending data string...")
                    ser.write(cached_data.encode('latin1'))
                    ser.flush()

                # OV: Open Validation Valve (Toggle Calibration)
                elif command.startswith('OV'):
                    is_calibrating = not is_calibrating
                    status_str = STATUS_CALIB if is_calibrating else STATUS_DEFAULT

                    # Refresh data immediately on toggle
                    cached_data = generate_data_string(is_calibrating)

                    log.info(f"Calibration valve toggled. Active: {is_calibrating}")
                    ser.write(b"OK")
                    ser.flush()

                # SI: Status Information
                elif command.startswith('SI'):
                    log.info(f"Sending status: {status_str}")
                    ser.write(status_str.encode('latin1'))
                    ser.flush()

                else:
                    # Echo or ignore unknown commands
                    log.warning(f"Unknown command: {command}")

            time.sleep(0.1)  # CPU saving

    except KeyboardInterrupt:
        log.info("Server shutting down...")
    except Exception as e:
        log.error(f"Runtime error: {e}")
    finally:
        ser.close()
        log.info("Serial port closed.")


if __name__ == '__main__':
    main()