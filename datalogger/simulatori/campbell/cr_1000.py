#!/usr/bin/env python3
# ----------------------------------------------------------------------
#  Copyright (c) 1995-2026, Ecometer s.n.c.
#  Author: Paolo Saudin.
#  Date  : 2026-07-31
# ----------------------------------------------------------------------
import json
import random
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime

# --- Configuration ---
DEFAULT_ADDRESS = '0.0.0.0'
DEFAULT_PORT = 1080
BUFFER_SIZE = 1024


class CR1000Handler(BaseHTTPRequestHandler):
    """Handler per simulare le risposte JSON del Campbell CR1000 con dati meteo."""

    def log_message(self, format, *args):
        """Override per log personalizzato in console."""
        now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
        print(f"Received @ {now} -> {self.path}")

    def do_GET(self):
        """Gestisce le richieste GET simulando i dati meteorologici e di sistema."""

        # Risposta HTTP OK
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

        # Inizializziamo una lista di valori (almeno 18 elementi per coprire l'indice 17)
        vals = [0.0] * 20

        # --- Mappatura Registri (Indici 4-17) ---

        # Sistema
        vals[4] = round(random.uniform(12.5, 14.2), 2)   # ST_BattV (Volt)
        vals[5] = round(random.uniform(20.0, 35.0), 1)   # ST_PTemp (Panel Temp)
        vals[6] = round(random.uniform(22.0, 38.0), 1)   # ST_CTemp (Case/Cell Temp)

        # Meteo
        vals[7] = round(random.uniform(-5.0, 35.0), 1)   # ME_Temperature (°C)
        vals[8] = round(random.uniform(30.0, 95.0), 0)   # ME_Humidity (%)
        vals[9] = round(random.uniform(980.0, 1035.0), 1)# ME_Pressure (hPa)

        # Vento
        ws = random.uniform(0.0, 12.0)
        vals[10] = round(ws, 1)                          # ME_WSpeed (m/s)
        vals[11] = round(ws + random.uniform(0, 5), 1)   # ME_WSpeed_max (Gust)
        vals[12] = round(random.uniform(0.0, 359.0), 0)  # ME_WDir (deg)
        vals[13] = round(vals[12] + random.uniform(-10, 10) % 360, 0) # ME_WDir_max

        # Allarmi (0 = OK, 1 = Alarm)
        vals[14] = random.choice([0, 0, 0, 0, 1])        # AL_Door
        vals[15] = 0                                     # AL_Power
        vals[16] = 0                                     # AL_PowerSupply
        vals[17] = 0                                     # AL_Temperature

        # Struttura JSON Campbell Scientific
        response_data = {
            "data": [
                {
                    "vals": vals,
                    "time": datetime.now().isoformat()
                }
            ]
        }

        now = datetime.now().strftime("%m/%d/%Y, %H:%M:%S")
        print(f"Sending @ {now} -> {response_data}")

        # Invio JSON
        self.wfile.write(json.dumps(response_data).encode('utf-8'))


def main():
    # Gestione porta da riga di comando
    port = DEFAULT_PORT
    if len(sys.argv) == 2:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port: {sys.argv[1]}. Using default port {DEFAULT_PORT}")

    server_address = (DEFAULT_ADDRESS, port)

    try:
        httpd = HTTPServer(server_address, CR1000Handler)
        print(f"--- Campbell CR1000 Simulator (Meteo) ---")
        print(f"Starting HTTP server on {DEFAULT_ADDRESS} port {port}")
        print("Mappatura: Registri 4-17 attivi.")
        httpd.serve_forever()

    except PermissionError:
        print(f"Error: Permission denied on port {port}. Try running with 'sudo'.")
    except KeyboardInterrupt:
        print("\nServer shutting down...")
    except Exception as e:
        print(f"Error during server startup: {e}")
    finally:
        if 'httpd' in locals():
            httpd.server_close()


if __name__ == '__main__':
    main()