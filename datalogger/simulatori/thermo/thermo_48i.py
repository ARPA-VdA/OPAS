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
# Permette di riavviare lo script senza attendere il timeout del sistema operativo sulla porta
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

# Bind the socket to the port
port = 9948
address = '192.168.168.47'
if arg1:
    port = arg1
server_address = (address, int(port))
print('starting up on {0} port {1}'.format(*server_address))
sock.bind(server_address)

# Listen for incoming connections
sock.listen(1)

while True:
    # Wait for a connection
    print('\nwaiting for a connection')
    connection, client_address = sock.accept()

    try:
        print('connection from {0}'.format(client_address))

        # Receive the data loop
        while True:
            try:
                data_raw = connection.recv(1024)

                # Se recv restituisce 0, il client si è disconnesso correttamente
                if not data_raw:
                    print('client closed connection')
                    break

                # Rimuove \r e \n e spazi extra
                data = data_raw.strip(b'\r\n ')

                now = datetime.now() # current date and time
                date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                print('received @ {0} -> {1} '.format(date_time, data))

                if data:
                    # main
                    if data == b'co':
                        print('sending co value')
                        v = random.uniform(0, 75)
                        connection.sendall('co {0:.2f}E+00 ppb*\r\n'.format(v).encode())

                    # diags
                    elif data == b'flow':
                        print('sending flow value')
                        v = random.uniform(1.050, 1.200)
                        connection.sendall('flow {0:.3f} l/m\r\n'.format(v).encode())

                    elif data == b'chamber temp':
                        print('sending chamber temp value')
                        v = random.uniform(40, 48)
                        connection.sendall('chamber temp {0:.1f} deg C\r\n'.format(v).encode())

                    elif data == b'internal temp':
                        print('sending internal temp value')
                        v = random.uniform(24, 30)
                        connection.sendall('internal temp {0:.1f} deg C\r\n'.format(v).encode())

                    elif data == b'motor':
                        print('sending motor value')
                        v = random.uniform(90, 110)
                        connection.sendall('motor {0:.0f} %\r\n'.format(v).encode())

                    elif data == b'pres':
                        print('sending pres value')
                        v = random.uniform(750, 755)
                        connection.sendall('pres {0:.1f} mm Hg\r\n'.format(v).encode())

                    elif data == b'ratio':
                        print('sending ratio value')
                        v = random.uniform(1.050000, 1.250000)
                        connection.sendall('ratio {0:.6f}*\r\n'.format(v).encode())

                    # calib
                    elif b'set zero' in data:
                        print('---- sending zero status ----')
                        connection.sendall(b'set zero ok\r\n')
                    elif b'set span' in data:
                        print('---- sending span status ----')
                        connection.sendall(b'set span ok\r\n')
                    elif b'set sample' in data:
                        print('---- sending sample status ----')
                        connection.sendall(b'set sample ok\r\n')

                    else:
                        # Echo per comandi non riconosciuti
                        connection.sendall(data + b'\r\n')

            except (ConnectionResetError, BrokenPipeError):
                print('Connection lost with client (Reset or Broken Pipe)')
                break
            except Exception as e:
                print('Error during communication: {0}'.format(e))
                break

    finally:
        # Pulisce la connessione prima di tornare in accept()
        connection.close()
        print('socket connection closed')