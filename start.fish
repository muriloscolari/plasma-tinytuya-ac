#!/usr/bin/env fish
# Inicia o backend do ar condicionado dentro do venv

set SCRIPT_DIR (dirname (realpath (status filename)))
cd $SCRIPT_DIR

if not test -d venv
    echo "venv não encontrado. Rode: python3 -m venv venv && venv/bin/pip install flask tinytuya"
    exit 1
end

echo "Iniciando backend do ar condicionado em http://localhost:5000 ..."
venv/bin/python app.py
