import os
import tinytuya
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response

@app.route('/', defaults={'path': ''}, methods=['OPTIONS'])
@app.route('/<path:path>', methods=['OPTIONS'])
def options_handler(path):
    return jsonify({}), 200

# Seus dados
DEVICE_ID = os.environ.get('DEVICE_ID')
LOCAL_KEY = os.environ.get('LOCAL_KEY')
DEVICE_IP = os.environ.get('DEVICE_IP')

# Dicionário de tradução: Nome do Portal -> ID do DP
DP_MAP = {
    "switch": "1",
    "temp_set": "2",
    "mode": "4",
    "mode_eco": "8",
    "heat": "12",
    "light": "13",
    "lock": "14",
    "switch_horizontal": "33",
    "sleep": "102",
    "health": "106"
}

# Mapeamento reverso de DPS para nomes legíveis
DP_NAMES = {v: k for k, v in DP_MAP.items()}

# Inicializa o dispositivo com IP real
d = tinytuya.Device(DEVICE_ID, DEVICE_IP, LOCAL_KEY)
d.set_version(3.3)
d.set_socketTimeout(5)

# ─── Endpoint de status estruturado para o widget ──────────────────────────────
@app.route('/api/status')
def api_status():
    try:
        raw = d.status()
        dps = raw.get('dps', {})

        # Modos possíveis: cold, hot, wind, auto
        mode_map = {
            'cold': 'cold',
            'hot':  'hot',
            'wind': 'wind',
            'auto': 'auto',
        }

        status = {
            "switch":   dps.get('1', False),
            "temp_set": dps.get('2', 240),    # em décimos de grau (ex: 240 = 24°C)
            "temp_cur": dps.get('3', 240),     # temperatura atual do sensor
            "mode":     dps.get('4', 'cold'),  # cold / hot / wind / auto
            "eco":      dps.get('8', False),
            "heat":     dps.get('12', False),
            "light":    dps.get('13', False),
            "sleep":    dps.get('102', False),
        }
        return jsonify({"ok": True, "status": status})
    except Exception as e:
        print(f"Erro ao ler status: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500

# ─── Endpoint de controle para o widget ────────────────────────────────────────
@app.route('/api/control', methods=['POST'])
def api_control():
    data = request.json
    action = data.get('action')
    value  = data.get('value')

    try:
        if action == 'power_on':
            d.set_value(int(DP_MAP['switch']), True)
        elif action == 'power_off':
            d.set_value(int(DP_MAP['switch']), False)
        elif action == 'set_temp':
            # value é temperatura em graus inteiros, multiplicamos por 10
            temp = int(float(value) * 10)
            d.set_value(int(DP_MAP['temp_set']), temp)
        elif action == 'set_mode':
            # value: 'cold' | 'hot' | 'wind' | 'auto'
            d.set_value(int(DP_MAP['mode']), value)
        elif action == 'toggle_eco':
            d.set_value(int(DP_MAP['mode_eco']), bool(value))
        elif action == 'toggle_light':
            d.set_value(int(DP_MAP['light']), bool(value))
        elif action == 'toggle_sleep':
            d.set_value(int(DP_MAP['sleep']), bool(value))
        else:
            return jsonify({"ok": False, "error": f"Ação desconhecida: {action}"}), 400

        return jsonify({"ok": True, "action": action, "value": value})
    except Exception as e:
        print(f"Erro ao controlar dispositivo: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500

# ─── Endpoints legados (mantidos para compatibilidade) ──────────────────────────
@app.route('/control', methods=['POST'])
def control():
    data = request.json
    value = data.get('value')

    if 'dp' in data:
        dp = int(data['dp'])
    elif 'code' in data and data['code'] in DP_MAP:
        dp = int(DP_MAP[data['code']])
    else:
        return jsonify({"status": "error", "message": "dp ou code inválido"}), 400

    try:
        result = d.set_value(dp, value)
        print(f"Enviado dp={dp} value={value} -> resposta: {result}")
        return jsonify({"status": "success", "dp": dp, "value": value})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/status')
def status():
    try:
        data = d.status()
        return jsonify(data.get('dps', {}))
    except Exception as e:
        print(f"Erro ao ler status: {e}")
        return jsonify({}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)