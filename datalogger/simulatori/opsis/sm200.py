#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2025, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2025-12-31
# ----------------------------------------------------------------------

import serial
import random
import re
from datetime import datetime, timedelta

# Open serial connection
# ser = serial.Serial("COM2", 19200, timeout=1)
ser = serial.Serial("/dev/ttySC1", 19200, timeout=1)

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

    response = f"#206,   {f0}, {f1},{f2},{f3},{f4}"
    return response

def get_207(index):
    """
    Generates a simulated response for the #207 command based on an index.
    """
    now = datetime.now()
    tomorrow = now + timedelta(days=1)

    # Prepare individual fields for clarity
    f1 = now.strftime("%Y%m%d")
    f2 = f"{random.randrange(0, 1):04}"
    f3 = f"{random.randrange(1000, 9999)}"
    f4 = tomorrow.strftime("%Y%m%d")
    f5 = f"{random.randrange(0, 1):04}"
    f6 = f"{random.uniform(1, 99):.3f}"
    f7 = f"{random.uniform(1, 10):.1f}"
    f8 = f"{random.uniform(1, 10):.1f}"
    f9 = f"{random.uniform(1, 10):.1f}"
    f10 = random.randrange(10, 99)
    f11 = random.randrange(10000, 99999)
    f12 = f"{random.uniform(100, 999):.1f}"
    f13 = f"{random.uniform(10, 99):.1f}"
    f14 = f"{random.uniform(100, 999):.1f}"
    f15 = random.randrange(100, 999)
    f16 = random.randrange(0, 9)
    f17 = random.randrange(0, 9)
    f18 = random.randrange(10000, 99999)
    f19 = f"{random.uniform(100, 999):.1f}"
    f20 = f"{random.uniform(10, 99):.1f}"
    f21 = f"{random.uniform(100, 999):.1f}"
    f22 = f"{random.uniform(10, 99):.1f}"
    f23 = f"{random.uniform(0, 1):.2f}"
    f24 = f"{random.uniform(0, 1):.3f}"
    f25 = f"{random.uniform(10, 99):.1f}"
    f26 = random.randrange(0, 9)
    f27 = random.randrange(0, 9)
    f28 = random.randrange(10, 99)

    response = (
        f"#207,   {index},{f1},{f2},{f3},{f4},{f5}, {f6},  {f7},  {f8}, {f9},  "
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
                    print(f"-> Sending: {response_206}")
                    
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
                        
                        print(f"-> Sending: {response_207}")
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
