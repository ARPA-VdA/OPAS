# Descrizione
Servizio per lettura dati da strumenti OPAS-DL

# Venv
python3 -m venv venv
source venv/bin/activate
Windows
.\venv_win\Scripts\Activate.ps1

# Install
pip install fastapi
pip install uvicorn
pip install pyserial
pip install pymodbus

# PyInstaller
pip install pyinstaller
Per creare il servizio
Usa lo script `build_dist.bat` (Windows) o `build_dist.sh` (Linux/macOS) dopo aver creato un virtualenv.

Esempio manuale (Windows PowerShell in un venv):
```
pip install -r requirements.txt pyinstaller
pyinstaller --onedir --name service_master service_master.spec
```

Per un singolo file finale usare `--onefile` e testare prima con `--onedir`.

# Lanciare il servizio
source venv/bin/activate
cd src/core
python3 service_master.py