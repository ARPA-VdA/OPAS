#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import serial
import random
import re
from datetime import datetime, timedelta

# Open serial connection
# ser = serial.Serial("COM2", 19200, timeout=1)
ser = serial.Serial("/dev/ttySC0", 19200, timeout=1)

def get_206():
    """
    Generates a simulated response for the #206 command.
    Example format: #206,   24, 2047,20151102,0000,8249
    """
    now = datetime.now()

    # Generate random data fields
    f0 = random.randrange(10, 99)
    f1 = random.randrange(1000, 9999)
    f2 = now.strftime("%Y%m%d")
    f3 = f"{random.randrange(0, 1):04}"
    f4 = random.randrange(1000, 9999)

    # Real
    # #206,   27,  119,20260808,0000,f9b4<CR>

    response = f"#206,   {f0}, {f1},{f2},{f3},{f4}"
    return response

def get_207(index):
    """
    Generates a simulated response for the #207 command based on an index.
    """
    now = datetime.now()
    tomorrow = now + timedelta(days=1)       # Down time

    # Prepare individual fields for clarity
    f0  = index                              # [XX] Record Id
    f1  = now.strftime("%Y%m%d")             # [--] Sampling start date
    f2  = f"{random.randrange(0, 1):04}"     # [--] Sampling start time
    f3  = f"{random.randrange(2358, 2359)}"  # [XX] Down time (min)
    f4  = tomorrow.strftime("%Y%m%d")        # [--] Sampling stop date
    f5  = f"{random.randrange(0, 1):04}"     # [--] Sampling stop time
    f6  = f"{random.uniform(1, 99):.3f}"     # [XX] Total sampling volume
    f7  = f"{random.uniform(1, 10):.1f}"     # [XX] Initial pressure drop across filter
    f8  = f"{random.uniform(1, 10):.1f}"     # [XX] Final pressure drop across filter
    f9  = f"{random.uniform(1, 10):.1f}"     # [XX] Relative standard deviation of flow rate during sampling
    f10 = random.randrange(10, 99)           # [XX] Background beta counts (Dark)
    f11 = random.randrange(10000, 99999)     # [XX] Clean filter beta count (Blank)
    f12 = f"{random.uniform(100, 999):.1f}"  # [XX] Average internal temparature during blank meas.
    f13 = f"{random.uniform(10, 99):.1f}"    # [XX] Average ambient pressure during blank meas.
    f14 = f"{random.uniform(100, 999):.1f}"  # [XX] Average Geiger voltage during blank meas.
    f15 = random.randrange(100, 999)         # [XX] Natural1 sample short life beta activity
    f16 = random.randrange(0, 9)             # [XX] Natural2 sample residual beta activity
    f17 = random.randrange(0, 9)             # [XX] Natural R sample residual beta activity
    f18 = random.randrange(10000, 99999)     # [XX] Collect sample beta counts
    f19 = f"{random.uniform(100, 999):.1f}"  # [XX] Average internal temperatura during sampling
    f20 = f"{random.uniform(10, 99):.1f}"    # [XX] Average ambient pressure during sampling
    f21 = f"{random.uniform(100, 999):.1f}"  # [XX] Average Geiger voltage during sampling
    f22 = f"{random.uniform(10, 99):.1f}"    # [XX] Average relative humidity during sampling
    f23 = f"{random.uniform(0, 1):.2f}"      # [XX] Total mass in sampled dust
    f24 = f"{random.uniform(0, 1):.3f}"      # [XX] Mass error in sampled dust
    f25 = f"{random.uniform(10, 99):.1f}"    # [XX] PM10
    f26 = random.randrange(0, 9)             # [XX] Pneumatic status
    f27 = random.randrange(0, 9)             # [XX] Beta status
    f28 = random.randrange(10, 99)           # [--] CRC

    # #207,32,20260808,0000,3985,20260809,0000,42.265,9.3,7.2,5.8,55,18320,950.9,43.5,226.3,129,8,7,23430,918.9,51.7,408.2,62.4,0.92,0.776,18.4,1,7,de50
    # #207,28,20260809,0000,3570,20260810,0000,40.949,8.1,7.0,1.7,87,15820,937.0,68.5,434.9,524,7,1,50903,311.2,58.9,402.1,37.3,0.16,0.347,61.5,4,7,de64
    # #207,27,20260808,0000,2358,20260809,0000,23.961,2.6,2.7,0.6,20,101341,313.1,97.6,604.3,90,9,1,100349,313.1,97.9,604.3,42.1,0.36,0.015,15.2,0,0,362c

    # Real
    # #207,   27,20260808,0000,2358,20260809,0000, 23.961,  2.6,  2.7, 0.6,  20,101341,313.1, 97.6,604.3,   90,    9,  1,100349,313.1, 97.9,604.3,42.1, 0.36,0.015,  15.2,   0,   0,362c<CR>

    # Response array size: 30
    # Pneumatic status: 5, Beta status: 2
    # Date 20260808
    # Converted date 20260808 to timestamp 1786147200
    # PM10 (array_idx=20): raw value 376.8
    # Down time (array_idx=0): raw value
    # Total sampling volume (array_idx=1): raw value 83
    # Initial pressure drop across filter (array_idx=2): raw value 20260808
    # Final pressure drop across filter (array_idx=3): raw value 0000
    # Relative standard deviation of flow rate during sampling (array_idx=4): raw value 6666
    # Background beta counts (Dark) (array_idx=5): raw value 20260809
    # Clean filter beta count (Blank) (array_idx=6): raw value 0000
    # Average internal temparature during blank meas. (array_idx=7): raw value 89.868
    # Average ambient pressure during blank meas. (array_idx=8): raw value 2.1
    # Average Geiger voltage during blank meas. (array_idx=9): raw value 4.0
    # Natural1 sample short life beta activity (array_idx=10): raw value 6.9
    # Natural2 sample residual beta activity (array_idx=11): raw value 22
    # Natural R sample residual beta activity (array_idx=12): raw value 58828
    # Collect sample beta counts (array_idx=13): raw value 249.5
    # Average internal temperatura during sampling (array_idx=14): raw value 95.3
    # Average ambient pressure during sampling (array_idx=15): raw value 193.3
    # Average Geiger voltage during sampling (array_idx=16): raw value 688
    # Average relative humidity during sampling (array_idx=17): raw value 5
    # Total mass in sampled dust (array_idx=18): raw value 2
    # Mass error in sampled dust (array_idx=19): raw value 59108
    # Pneumatic status (array_idx=21): raw value 20.3
    # Beta status (array_idx=22): raw value 846.4
    # Record Id (array_idx=23): raw value 61.3

    response = (
        f"#207,   {f0},{f1},{f2},{f3},{f4},{f5}, {f6},  {f7},  {f8}, {f9},  "
        f"{f10}, {f11},{f12}, {f13},{f14},  {f15},    {f16},  {f17}, {f18},{f19}, "
        f"{f20},{f21},{f22}, {f23},{f24},  {f25},   {f26},   {f27},de{f28}"
    )
    return response

def main():
    print("--- MASTER main started ---")

    try:
        while True:
            # Read data from serial port
            buffer_data = ser.readline()

            if buffer_data:
                # Decode bytes to string
                try:
                    command = buffer_data.decode().strip()
                except UnicodeDecodeError:
                    continue

                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]

                # Check for command #206
                if command.startswith('#206'):
                    print(f"<- Received command {command} @ {timestamp}")

                    response_206 = get_206()
                    print(f"-> Sending: {response_206} @ {timestamp}")

                    # Send data back through serial connection
                    ser.write(f"{response_206}\r".encode())

                # Check for command #207
                elif command.startswith('#207'):
                    print(f"<- Received command {command} @ {timestamp}")

                    # Extract "index" from command using regex
                    # It looks for the first two digits after #207XXXX
                    match = re.search(r"#207\d+(\d\d)", command)
                    if match:
                        idx = match.group(1)
                        response_207 = get_207(idx)

                        print(f"-> Sending: {response_207} @ {timestamp}")
                        # Send data back through serial connection
                        ser.write(f"{response_207}\r".encode())
                    else:
                        print("!! Invalid #207 command format")

    except KeyboardInterrupt:
        print("\n--- Script terminated by user ---")
    finally:
        ser.close()

if __name__ == '__main__':
    main()
