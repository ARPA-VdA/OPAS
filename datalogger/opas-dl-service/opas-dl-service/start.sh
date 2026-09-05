#!/usr/bin/env bash
set -e

# Vai nella cartella dello script, qualunque sia la cwd al momento del lancio
cd "$(dirname "$0")"

# --- rileva python ---
if command -v python3 &>/dev/null; then
    PYTHON=python3
elif command -v python &>/dev/null; then
    PYTHON=python
else
    echo "ERRORE: python non trovato nel PATH."
    exit 1
fi

# --- venv ---
if [ ! -d venv ]; then
    echo "Creo il virtual environment..."
    "$PYTHON" -m venv venv
fi

# --- dipendenze ---
if [ -f requirements.txt ]; then
    echo "Installo le dipendenze..."
    venv/bin/pip install --quiet -r requirements.txt
else
    echo "ATTENZIONE: requirements.txt non trovato, salto l'installazione."
fi

# --- avvio ---
echo "Avvio il servizio..."
exec venv/bin/python src/core/service_master.py
