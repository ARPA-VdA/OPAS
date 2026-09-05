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
DEFAULT_PORT = "COM4"  # Windows: COM1-COM9, Linux: /dev/ttyUSB0, etc.
DEFAULT_BAUDRATE = 9600
DEFAULT_TIMEOUT = 1

# Protocol constants
STX = chr(0x02)
ETX = chr(0x03)

# TEOM 1400a Registers
REGISTERS = {
    "K0 7":  "Mass Rate",
    "K0 8":  "Mass Concentration",
    "K0 9":  "Total mass",
    "K0 26": "Current air temperature",
    "K0 35": "Filter loading",
    "K0 39": "Current main flow",
    "K0 40": "Current auxiliary flow",
    "K0 41": "Status condition",
    "K0 58": "Read hour average mass",
}


def generate_register_value(register_key):
    """
    Generate realistic value for a TEOM register.
    Returns a value based on the register type.
    """
    if register_key == "K0 7":
        # Mass Rate (µg/m³/h)
        return round(random.uniform(0.0, 50.0), 2)
    elif register_key == "K0 8":
        # Mass Concentration (µg/m³)
        return round(random.uniform(10.0, 150.0), 1)
    elif register_key == "K0 9":
        # Total mass (µg)
        return round(random.uniform(100.0, 5000.0), 1)
    elif register_key == "K0 26":
        # Current air temperature (°C)
        return round(random.uniform(-10.0, 45.0), 1)
    elif register_key == "K0 35":
        # Filter loading (%)
        return round(random.uniform(0.0, 100.0), 1)
    elif register_key == "K0 39":
        # Current main flow (L/min)
        return round(random.uniform(15.0, 20.0), 2)
    elif register_key == "K0 40":
        # Current auxiliary flow (L/min)
        return round(random.uniform(2.0, 5.0), 2)
    elif register_key == "K0 41":
        # Status condition (hex or numeric)
        return random.randint(0, 255)
    elif register_key == "K0 58":
        # Read hour average mass (µg/m³)
        return round(random.uniform(10.0, 150.0), 1)
    else:
        # Generic value
        return round(random.uniform(0.0, 100.0), 2)


def create_response(address, register, value):
    """
    Create TEOM 1400a response frame.
    Frame format: STX + "4AREG " + address + " " + register + " " + value + ETX + CRLF
    Example: 0x02 + "4AREG K0 8 100.5" + 0x03 + CR + LF
    """
    response = f"4AREG {address} {register} {value}"
    frame = STX + response + ETX + "\r\n"
    return frame


def parse_command(raw_command):
    """
    Parse incoming command.
    Expected format: STX + "4AREG <address> <register>" + ETX + CRLF
    Returns (address, register) or (None, None) if parsing fails.
    """
    try:
        # Remove STX and ETX markers
        if raw_command.startswith(STX) and ETX in raw_command:
            command = raw_command[1:raw_command.index(ETX)].strip()
        else:
            return None, None

        # Parse "4AREG <address> <register>"
        parts = command.split()
        if len(parts) >= 3 and parts[0] == "4AREG":
            address = parts[1]
            register = f"{parts[2]} {parts[3]}" if len(parts) > 3 else parts[2]
            return address, register

        return None, None
    except Exception as e:
        return None, None


def handle_command(command):
    """Process incoming command and return appropriate response."""
    address, register = parse_command(command)

    if address is None or register is None:
        return None

    # Generate value for the register
    value = generate_register_value(register)

    # Create response
    response = create_response(address, register, value)

    return response


def main():
    """Main server loop."""
    port = DEFAULT_PORT
    baudrate = DEFAULT_BAUDRATE

    # Parse command-line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Usage: 1400a.py [PORT] [BAUDRATE]")
            print("Examples:")
            print("  1400a.py                     # Use default COM4 at 9600 baud")
            print("  1400a.py COM1                # Use COM1 at 9600 baud")
            print("  1400a.py /dev/ttyUSB0        # Use /dev/ttyUSB0 on Linux")
            print("  1400a.py COM1 19200          # Use COM1 at 19200 baud")
            print("\nSupported TEOM 1400a Registers:")
            for reg, desc in REGISTERS.items():
                print(f"  {reg:15} - {desc}")
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
        print(f"[{now}] TEOM 1400a simulator started")
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

                        # Check if we have a complete frame (ends with CRLF after ETX)
                        if ETX in buffer and '\r\n' in buffer:
                            command = buffer[:buffer.index('\r\n') + 2]
                            buffer = buffer[buffer.index('\r\n') + 2:]

                            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                            print(f"[{now}] RX: {repr(command)}")

                            # Process command and get response
                            response = handle_command(command)

                            if response is not None:
                                ser.write(response.encode('utf-8'))
                                print(f"[{now}] TX: {repr(response)}")
                            else:
                                print(f"[{now}] Parse error or unknown command")

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
