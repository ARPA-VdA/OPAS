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
from datetime import datetime, timedelta

# --- Configuration ---
DEFAULT_PORT = "COM6"  # Windows: COM1-COM9, Linux: /dev/ttyUSB0, etc.
DEFAULT_BAUDRATE = 9600
DEFAULT_TIMEOUT = 1

# Tape advance counter
TAPE_ADVANCE_COUNT = 0


def generate_measurement_data(use_bcbb=False):
    """
    Generate MAGEE AE33 measurement data.

    Format: Date Time Timebase RefCh1 Sen1Ch1 Sen2Ch1 RefCh2 Sen1Ch2 Sen2Ch2 ... [K1-K7] TapeAdvCount ID_com1 ID_com2 ID_com3 fields_i
    Total: minimum 66 fields, up to 71

    use_bcbb: If True, use BCBB (ng/m3) instead of BB (%), used for W1 command
    """
    global TAPE_ADVANCE_COUNT

    # Date and Time
    now = datetime.now()
    date_str = now.strftime("%Y/%m/%d")
    time_str = now.strftime("%H:%M:%S")
    timebase = 60

    # Reference and sensitivity values for 7 channels (BC1-BC7)
    data_fields = [date_str, time_str, str(timebase)]

    # Generate channel data (Ref, Sen1, Sen2) for 7 channels
    for ch in range(7):
        ref = random.randint(800000, 950000)
        sen1 = random.randint(500000, 700000)
        sen2 = random.randint(650000, 850000)
        data_fields.extend([str(ref), str(sen1), str(sen2)])

    # Flow values
    flow1 = random.randint(3000, 4000)
    flow2 = random.randint(1000, 2000)
    flow_c = random.randint(4500, 5500)
    data_fields.extend([str(flow1), str(flow2), str(flow_c)])

    # Physical measurements
    pressure = 101325  # Pa (atmospheric pressure)
    temperature = round(random.uniform(15.0, 30.0), 2)

    # BB value: either % (D1) or ng/m3 (W1)
    if use_bcbb:
        bb_value = round(random.uniform(100, 1000), 0)  # ng/m3
    else:
        bb_value = round(random.uniform(0.0, 50.0), 1)  # %

    data_fields.extend([
        str(pressure),
        str(temperature),
        str(bb_value)
    ])

    # Container and supply temperatures
    cont_temp = random.randint(25, 40)
    supply_temp = random.randint(30, 45)
    data_fields.extend([str(cont_temp), str(supply_temp)])

    # Status values
    status = 0
    cont_status = 0
    detect_status = 10
    led_status = 10
    valve_status = random.randint(0, 1)
    led_temp = random.randint(1100, 1300)
    data_fields.extend([
        str(status),
        str(cont_status),
        str(detect_status),
        str(led_status),
        str(valve_status),
        str(led_temp)
    ])

    # BC values (BC11, BC12, BC1, BC21, BC22, BC2, ..., BC71, BC72, BC7)
    for ch in range(7):
        bc1 = random.randint(5000, 7000)
        bc2 = random.randint(5500, 7500)
        bc_sum = random.randint(5500, 7500)
        data_fields.extend([str(bc1), str(bc2), str(bc_sum)])

    # K values (K1-K7) - calibration coefficients
    for k in range(7):
        k_val = round(random.uniform(0.003, 0.007), 9)
        data_fields.append(f"{k_val:.9f}")

    # Tape advance count
    TAPE_ADVANCE_COUNT += random.randint(1, 5)
    data_fields.append(str(TAPE_ADVANCE_COUNT))

    # ID communication values
    data_fields.extend([str(random.randint(0, 10)), str(random.randint(0, 10)), str(random.randint(0, 10))])

    # Field count (last field)
    data_fields.append(str(len(data_fields)))

    return " ".join(data_fields)


def generate_tape_advance_count():
    """Generate tape advance count response for $AE33:A command."""
    global TAPE_ADVANCE_COUNT
    TAPE_ADVANCE_COUNT += random.randint(0, 3)
    return str(TAPE_ADVANCE_COUNT)


def parse_command(raw_command):
    """
    Parse incoming command.
    Expected commands:
    - $AE33:D1\r (request last measurement with BB %)
    - $AE33:W1\r (request last measurement with BCBB ng/m3)
    - $AE33:A\r  (request tape advance count)
    """
    cmd = raw_command.strip().upper()

    if cmd == "$AE33:D1":
        return "D1"
    elif cmd == "$AE33:W1":
        return "W1"
    elif cmd == "$AE33:A":
        return "A"
    else:
        return None


def handle_command(command):
    """Process incoming command and return appropriate response."""
    cmd_type = parse_command(command)

    if cmd_type == "D1":
        # Request with BB (%)
        data = generate_measurement_data(use_bcbb=False)
        response = data + "\r\n"
        return response

    elif cmd_type == "W1":
        # Request with BCBB (ng/m3)
        data = generate_measurement_data(use_bcbb=True)
        response = data + "\r\n"
        return response

    elif cmd_type == "A":
        # Tape advance count
        count = generate_tape_advance_count()
        response = count + "\r\n"
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
            print("Usage: ae33.py [PORT] [BAUDRATE]")
            print("Examples:")
            print("  ae33.py                      # Use default COM6 at 9600 baud")
            print("  ae33.py COM1                 # Use COM1 at 9600 baud")
            print("  ae33.py /dev/ttyUSB0         # Use /dev/ttyUSB0 on Linux")
            print("  ae33.py COM1 19200           # Use COM1 at 19200 baud")
            print("\nSupported Commands:")
            print("  $AE33:D1  - Request last measurement (with BB %)")
            print("  $AE33:W1  - Request last measurement (with BCBB ng/m3)")
            print("  $AE33:A   - Request tape advance count")
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
        print(f"[{now}] MAGEE AE33 Aethalometer simulator started")
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
                        if '\r' in buffer:
                            # Extract command line
                            command = buffer[:buffer.index('\r')]
                            buffer = buffer[buffer.index('\r') + 1:]

                            if command.strip():
                                now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                print(f"[{now}] RX: {repr(command)}")

                                # Process command and get response
                                response = handle_command(command)

                                if response is not None:
                                    ser.write(response.encode('utf-8'))
                                    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                    # Truncate long response for display
                                    display_resp = response[:120] + "..." if len(response) > 120 else response
                                    print(f"[{now}] TX: {repr(display_resp.strip())}")
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
