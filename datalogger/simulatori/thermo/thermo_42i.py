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
# Opzionale: permette di riavviare subito lo script senza errore "Address already in use"
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

# Bind the socket to the port
port = 9942
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
                data = connection.recv(1024)

                # Se recv restituisce 0 byte, il client ha chiuso la connessione
                if not data:
                    print('client closed connection')
                    break

                # Pulizia dati (rimozione newline e carriage return)
                data = data.strip(b'\r\n')

                now = datetime.now()
                date_time = now.strftime("%m/%d/%Y, %H:%M:%S")
                print('received @ {0} -> {1} '.format(date_time, data))

                # Logica delle risposte
                if data == b'nox':
                    v = random.uniform(0, 75)
                    connection.sendall('nox {0:.2f}E+00 ppb*\r\n'.format(v).encode())
                elif data == b'no':
                    v = random.uniform(0, 65)
                    connection.sendall('no {0:.2f}E+00 ppb*\r\n'.format(v).encode())
                elif data == b'no2':
                    v = random.uniform(0, 25)
                    connection.sendall('no2 {0:.2f}E+00 ppb*\r\n'.format(v).encode())


                # Temperature
                elif data == b'conv temp':
                    v = random.uniform(324.5, 325.5)
                    connection.sendall('conv temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'cooler temp':
                    v = random.uniform(-1.2, -0.8)
                    connection.sendall('cooler temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'internal temp':
                    v = random.uniform(32.0, 36.0)
                    connection.sendall('internal temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'perm gas temp':
                    v = random.uniform(44.9, 45.1)
                    connection.sendall('perm gas temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'pmt temp':
                    v = random.uniform(-5.2, -4.8)
                    connection.sendall('pmt temp {0:.1f} deg C\r\n'.format(v).encode())

                elif data == b'react temp':
                    v = random.uniform(49.8, 50.2)
                    connection.sendall('react temp {0:.1f} deg C\r\n'.format(v).encode())

                # Parametri Fisici
                elif data == b'flow':
                    v = random.uniform(0.595, 0.605)
                    connection.sendall('flow {0:.3f} lpm\r\n'.format(v).encode())

                elif data == b'pres':
                    v = random.uniform(498.0, 502.0)
                    connection.sendall('pres {0:.1f} mmHg\r\n'.format(v).encode())

                elif data == b'pmt voltage':
                    v = random.uniform(-802.0, -798.0)
                    connection.sendall('pmt voltage {0:.1f} V\r\n'.format(v).encode())

                # Coefficienti e Background
                elif data == b'nox coef':
                    connection.sendall(b'nox coef 1.005\r\n')

                elif data == b'no coef':
                    connection.sendall(b'no coef 1.002\r\n')

                elif data == b'no2 coef':
                    connection.sendall(b'no2 coef 1.000\r\n')

                elif data == b'nox bkg':
                    v = random.uniform(0.15, 0.35)
                    connection.sendall('nox bkg {0:.2f} ppb\r\n'.format(v).encode())

                elif data == b'no bkg':
                    v = random.uniform(0.15, 0.35)
                    connection.sendall('no bkg {0:.2f} ppb\r\n'.format(v).encode())


                elif b'set zero' in data:
                    time.sleep(0.25)
                    connection.sendall(b'set zero ok\r\n')
                elif b'set span' in data:
                    time.sleep(0.25)
                    connection.sendall(b'set span ok\r\n')
                elif b'set sample' in data:
                    time.sleep(0.25)
                    connection.sendall(b'set sample ok\r\n')
                else:
                    # Echo per comandi non riconosciuti (aggiunto \n per chiarezza)
                    connection.sendall(data + b'\r\n')

            except (ConnectionResetError, BrokenPipeError):
                print('Connection lost abruptly with client')
                break
            except Exception as e:
                print('Error during communication: {0}'.format(e))
                break

    finally:
        # Assicura la chiusura del socket corrente prima di tornare ad accept()
        connection.close()
        print('connection closed, returning to listen mode')