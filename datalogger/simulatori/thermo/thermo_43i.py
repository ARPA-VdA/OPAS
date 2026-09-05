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
# Permette di riutilizzare subito la porta se lo script viene riavviato
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

# Bind the socket to the port
port = 9943
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

        # Receive the data in small chunks and retransmit it
        while True:
            try:
                data_raw = connection.recv(1024)

                # Se recv restituisce 0 byte, il client si è disconnesso correttamente
                if not data_raw:
                    print('client closed connection')
                    break

                # Pulizia dati: rimuove \r e \n sia singolarmente che in combinazione
                data = data_raw.strip(b'\r\n')

                now = datetime.now() # current date and time
                date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                print('received @ {0} -> {1} '.format(date_time, data))

                # main logic
                if data == b'so2':
                    print('sending so2 value')
                    v = random.uniform(-1.9, 2)
                    connection.sendall('so2 {0:.3f}E+00 ppb*\r\n'.format(v).encode())

                elif data == b'conv temp':
                    print('sending conv temp value')
                    v = random.uniform(40, 48)
                    connection.sendall('conv temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'flow':
                    print('sending flow value')
                    v = random.uniform(0.495, 0.510)
                    connection.sendall('flow {0:.3f} l/m\r\n'.format(v).encode())

                elif data == b'internal temp':
                    print('sending internal temp value')
                    v = random.uniform(24, 30)
                    connection.sendall('internal temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'perm gas temp':
                    print('sending perm gas temp value')
                    v = random.uniform(40, 50)
                    connection.sendall('perm gas temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'pmt voltage':
                    print('sending pmt voltage value')
                    v = random.uniform(-5, -520)
                    connection.sendall('pmt voltage {0:.1f} volts\r\n'.format(v).encode())

                elif data == b'pres':
                    print('sending pres value')
                    v = random.uniform(750, 755)
                    connection.sendall('pres {0:.1f} mm Hg\r\n'.format(v).encode())

                elif data == b'react temp':
                    print('sending react temp value')
                    v = random.uniform(40, 48)
                    connection.sendall('react temp {0:.1f} deg C\r\n'.format(v).encode())

                # calib
                elif b'set zero' in data:
                    print('---- sending zero status ----')
                    time.sleep(0.05)
                    connection.sendall(b'set zero ok\r\n')
                elif b'set span' in data:
                    print('---- sending span status ----')
                    time.sleep(0.05)
                    connection.sendall(b'set span ok\r\n')
                elif b'set sample' in data:
                    print('---- sending sample status ----')
                    time.sleep(0.05)
                    connection.sendall(b'set sample ok\r\n')

                else:
                    # Echo per comandi non riconosciuti
                    connection.sendall(data + b'\r\n')

            except (ConnectionResetError, BrokenPipeError):
                print('Connection lost abruptly with client')
                break
            except Exception as e:
                print('Error: {0}'.format(e))
                break

    finally:
        # Pulisce la connessione e torna in ascolto
        connection.close()
        print('socket cleaned up')