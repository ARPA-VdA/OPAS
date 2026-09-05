#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import sys
import random
import socket
from datetime import datetime
import time

# get port
arg1 = None
if len(sys.argv) == 2:
    arg1 = sys.argv[1]

# Create a TCP/IP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# Permette il riavvio immediato sulla stessa porta
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

# Bind the socket to the port
port = 9949
address = '192.168.168.47'
if arg1:
    port = arg1
server_address = (address, int(port))
print('starting up on {0} port {1}'.format(*server_address))
sock.bind(server_address)

# Listen for incoming connections
sock.listen(1)

while True:
    print('\nwaiting for a connection')
    connection, client_address = sock.accept()

    try:
        print('connection from {0}'.format(client_address))

        while True:
            try:
                data_raw = connection.recv(1024)

                # Se recv è vuoto, il client ha chiuso la connessione
                if not data_raw:
                    print('client closed connection')
                    break

                # Pulisce i dati ricevuti
                data = data_raw.strip(b'\r\n ')

                now = datetime.now()
                date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                print('received @ {0} -> {1} '.format(date_time, data))

                if data:
                    # main logic
                    if data == b'o3':
                        v = random.uniform(0, 75)
                        connection.sendall('o3 {0:.2f}E+00 ppb*\r\n'.format(v).encode())

                    # diags
                    elif data == b'flow a':
                        v = random.uniform(0.550, 0.620)
                        connection.sendall('flow a {0:.3f} l/m\r\n'.format(v).encode())

                    elif data == b'flow b':
                        v = random.uniform(0.550, 0.620)
                        connection.sendall('flow b {0:.3f} l/m\r\n'.format(v).encode())

                    elif data == b'o3 lamp temp':
                        v = random.uniform(65.0, 70.0)
                        connection.sendall('o3 lamp temp {0:.1f} deg C\r\n'.format(v).encode())

                    elif data == b'lamp voltage bench':
                        v = random.uniform(9, 11)
                        connection.sendall('lamp voltage bench {0:.1f} %\r\n'.format(v).encode())

                    elif data == b'lamp voltage oz':
                        v = random.uniform(10, 14)
                        connection.sendall('lamp voltage oz {0:.1f} V\r\n'.format(v).encode())

                    elif data == b'pres':
                        v = random.uniform(750, 765)
                        connection.sendall('pres {0:.1f} mm Hg\r\n'.format(v).encode())

                    elif data == b'cell a int':
                        v = random.uniform(97000, 99000)
                        connection.sendall('cell a int {0:.0f} Hz\r\n'.format(v).encode())

                    elif data == b'cell b int':
                        v = random.uniform(97000, 99000)
                        connection.sendall('cell b int {0:.0f} Hz\r\n'.format(v).encode())

                    elif data == b'bench temp':
                        v = random.uniform(30, 35)
                        connection.sendall('bench temp {0:.1f} deg C\r\n'.format(v).encode())

                    elif data == b'lamp temp':
                        v = random.uniform(50, 60)
                        connection.sendall('lamp temp {0:.1f} deg C\r\n'.format(v).encode())

                    elif data == b'o3 bkg':
                        v = random.uniform(5.0, 6.0)
                        connection.sendall('o3 bkg {0:.1f} ppb\r\n'.format(v).encode())

                    elif data == b'o3 coef':
                        v = random.uniform(0.990, 1.010)
                        connection.sendall('o3 coef {0:.3f}\r\n'.format(v).encode())

                    # calib
                    elif b'set zero' in data:
                        connection.sendall(b'set zero ok\r\n')
                    elif b'set level 1' in data:
                        connection.sendall(b'set level 1 ok\r\n')
                    elif b'set sample' in data:
                        connection.sendall(b'set sample ok\r\n')

                    else:
                        connection.sendall(data + b'\r\n')

            except (ConnectionResetError, BrokenPipeError):
                print('Connection lost abruptly with client')
                break
            except Exception as e:
                print('Error: {0}'.format(e))
                break

    finally:
        connection.close()
        print('connection closed, waiting for new client')