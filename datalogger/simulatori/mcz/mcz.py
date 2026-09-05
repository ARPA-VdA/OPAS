#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import sys
import random
import serial
import time
from datetime import datetime

# --- Configuration ---
DEFAULT_PORT = "/dev/ttySC0"  # Windows: COM1-COM9, Linux: /dev/ttySC0, etc.
DEFAULT_BAUDRATE = 115200
DEFAULT_TIMEOUT = 1

# MCZ Parameter definitions (ID, Name, Min value, Max value, Divisor)
MCZ_PARAMETERS = [
    ("001", "ID-Flow", 3500, 4200, 1000),           # Flow rate
    ("002", "ID-Temp", -1000, 3500, 1000),          # Temperature
    ("003", "ID-Press", 9000, 10000, 1000),         # Pressure
    ("004", "ID-Umid", 700, 1100, 1),               # Humidity
    ("005", "ID-T.Filt", -5000, 2000, 10),          # Filter temperature
    ("006", "ID-T.Stor", -10000, 3000, 1000),       # Storage temperature
    ("007", "ID-probe", 1000, 9000, 1000),          # Probe
    ("008", "ID-ActVol", 2000, 5000, 10000),        # Actual volume
    ("009", "ID-lp.Vol", 5000, 6000, 10000),        # LP Volume
    ("010", "ID-P.Diff", 2000, 7000, 10000),        # Pressure difference
]


def generate_exponent():
    """
    Generate random exponent value.
    Range: -2 to +4 (represents 10^n)
    """
    return random.randint(-2, 4)


def create_parameter_string(param_id, param_name, min_val, max_val, divisor):
    """
    Create a formatted parameter string.
    Format: nnn sssss+ee hh hh nnn hhhhhh
    where:
    - nnn: parameter ID (001-010)
    - sssss: signed value (nnnn or -nnnn)
    - ee: exponent (sign + 2 digits)
    - hh hh: operating status and error status
    - nnn: serial number
    - hhhhhh: free field
    """
    # Generate random value
    value = random.randint(min_val, max_val)
    exponent = generate_exponent()

    # Format value with sign
    value_str = f"{value:+05d}"
    exponent_str = f"{exponent:+03d}"

    # Generate status codes
    #p_status = f"{random.randint(0, 255):02X}"
    op_status = f"{random.randint(0, 99):02d}"
    err_status = f"{random.randint(0, 99):02d}"
    serial_num = f"{random.randint(0, 999):03d}"
    free_field = f"{random.randint(0, 999999):06d}"

    # Build parameter string
    param_str = f"{param_id} {value_str}{exponent_str} {op_status} {err_status} {serial_num} {free_field}"

    return param_str


def create_md10_response():
    """
    Create complete MD10 response with all 10 parameters.
    Format: MD10 <param1> <param2> ... <param10>
    """
    response = "MD10"

    for param_id, param_name, min_val, max_val, divisor in MCZ_PARAMETERS:
        param_str = create_parameter_string(param_id, param_name, min_val, max_val, divisor)
        response += " " + param_str

    return response


def parse_command(raw_command):
    """
    Parse incoming command.
    Expected: "DA\r" or "DA\n"
    Returns True if command is "DA", False otherwise.
    """
    cmd = raw_command.strip().upper()
    return cmd == "DA"


def handle_command(command):
    """Process incoming command and return appropriate response."""
    if parse_command(command):
        response = create_md10_response() + "\r"
        return response
    else:
        return None


def main():
    """Main server loop."""
    port = DEFAULT_PORT
    baudrate = DEFAULT_BAUDRATE

    # Parse command-line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Usage: mcz.py [PORT] [BAUDRATE]")
            print("Examples:")
            print("  mcz.py                       # Use default COM5 at 9600 baud")
            print("  mcz.py COM1                  # Use COM1 at 9600 baud")
            print("  mcz.py /dev/ttyUSB0          # Use /dev/ttyUSB0 on Linux")
            print("  mcz.py COM1 19200            # Use COM1 at 19200 baud")
            print("\nMCZ Parameters:")
            for param_id, param_name, _, _, _ in MCZ_PARAMETERS:
                print(f"  {param_id} - {param_name}")
            return
        else:
            port = sys.argv[1]

    if len(sys.argv) > 2:
        try:
            baudrate = int(sys.argv[2])
        except ValueError:
            print(f"Invalid baudrate: {sys.argv[2]}")
            return

    # Try to open serial port
    try:
        ser = serial.Serial(port, baudrate, timeout=DEFAULT_TIMEOUT)
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{now}] MCZ Air Quality Monitor simulator started")
        print(f"[{now}] Port: {port}, Baudrate: {baudrate}")
    except serial.SerialException as e:
        print(f"Error opening serial port {port}: {e}")
        print("\nTroubleshooting:")
        print("- On Windows: Install com0com or another virtual COM port software")
        print("- On Linux: Create virtual ports with: socat -d -d pty,raw,echo=0 pty,raw,echo=0")
        print("- Check if the port exists and is accessible")
        return
    except Exception as e:
        print(f"Unexpected error: {e}")
        return

    try:
        buffer = ""
        while True:
            # Check if there's data to read
            if ser.in_waiting > 0:
                try:
                    # Read one byte at a time
                    byte = ser.read(1)
                    if byte:
                        char = byte.decode('utf-8', errors='ignore')
                        buffer += char

                        # Check if we have a complete frame (ends with CR)
                        if '\r' in buffer or '\n' in buffer:
                            # Extract command line
                            if '\r' in buffer:
                                command = buffer[:buffer.index('\r')]
                                buffer = buffer[buffer.index('\r') + 1:]
                            else:
                                command = buffer[:buffer.index('\n')]
                                buffer = buffer[buffer.index('\n') + 1:]

                            if command.strip():
                                now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                print(f"[{now}] RX: {repr(command)}")

                                # Process command and get response
                                response = handle_command(command)

                                if response is not None:
                                    ser.write(response.encode('utf-8'))
                                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                    # Truncate long response for display
                                    display_resp = response[:100] + "..." if len(response) > 100 else response
                                    print(f"[{now}] TX: {repr(display_resp)}")
                                else:
                                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                    print(f"[{now}] Unknown command: {repr(command)}")

                except UnicodeDecodeError:
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"[{now}] Error decoding received data")
                except Exception as e:
                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    print(f"[{now}] Error processing command: {e}")
            else:
                # Small delay to avoid busy-waiting
                time.sleep(0.01)

    except KeyboardInterrupt:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"\n[{now}] Shutting down...")
    except Exception as e:
        print(f"Runtime error: {e}")
    finally:
        if ser.is_open:
            ser.close()
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"[{now}] Serial port closed")


if __name__ == '__main__':
    main()
