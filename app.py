import os
import threading
import tinytuya
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
device_lock = threading.Lock()

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

# Seus dados (suporta com ou sem prefixo TUYA_)
DEVICE_ID = os.environ.get('DEVICE_ID') or os.environ.get('TUYA_DEVICE_ID')
LOCAL_KEY = os.environ.get('LOCAL_KEY') or os.environ.get('TUYA_LOCAL_KEY')
DEVICE_IP = os.environ.get('DEVICE_IP') or os.environ.get('TUYA_DEVICE_IP')

# Dicionário de tradução: Nome do Portal -> ID do DP
DP_MAP = {
    "switch": "1",
    "temp_set": "2",
    "temp_cur": "3",
    "mode": "4",
    "fan_speed": "5",
    "mode_eco": "8",
    "heat": "12",
    "light": "13",
    "lock": "14",
    "swing": "33",
    "switch_horizontal": "33",
    "sleep": "102",
    "health": "106"
}

# Mapeamento reverso de DPS para nomes legíveis
DP_NAMES = {v: k for k, v in DP_MAP.items()}

# Normalização de velocidades do vento (DP 5)
FAN_ALIASES = {
    "medium": "mid",
    "med": "mid",
    "mute": "low",
    "quiet": "low",
    "turbo": "high"
}

# Cria o dispositivo sob demanda para evitar estado obsoleto após perda de rede
def get_device():
    if not all([DEVICE_ID, DEVICE_IP, LOCAL_KEY]):
        raise ValueError("DEVICE_ID, DEVICE_IP ou LOCAL_KEY não foram definidos no .env")
    dev = tinytuya.Device(DEVICE_ID, DEVICE_IP, LOCAL_KEY)
    dev.set_version(3.3)
    dev.set_socketTimeout(5)
    return dev

# ─── Endpoint de status estruturado para o widget ──────────────────────────────
@app.route('/api/status')
def api_status():
    try:
        with device_lock:
            raw = get_device().status()
        if not raw or 'Error' in raw or 'dps' not in raw:
            error_msg = raw.get('Error', 'Falha ao comunicar com o dispositivo') if isinstance(raw, dict) else 'Sem resposta do dispositivo'
            return jsonify({"ok": False, "error": error_msg}), 500

        dps = raw.get('dps', {})

        raw_fan = str(dps.get('5', 'auto')).lower()
        fan_speed = FAN_ALIASES.get(raw_fan, raw_fan)
        if fan_speed not in ('auto', 'low', 'mid', 'high'):
            fan_speed = 'auto'

        status = {
            "switch":    dps.get('1', False),
            "temp_set":  dps.get('2', 240),    # em décimos de grau (ex: 240 = 24°C)
            "temp_cur":  dps.get('3', 240),    # temperatura atual do sensor
            "mode":      dps.get('4', 'cold'), # cold / hot / wind / wet / auto
            "fan_speed": fan_speed,            # auto / low / mid / high
            "eco":       dps.get('8', False),
            "heat":      dps.get('12', False),
            "light":     dps.get('13', False),
            "lock":      dps.get('14', False),
            "swing":     dps.get('33', False),
            "sleep":     dps.get('102', False),
            "health":    dps.get('106', False),
        }
        return jsonify({"ok": True, "status": status})
    except Exception as e:
        print(f"Erro ao ler status: {e}")
        return jsonify({"ok": False, "error": str(e)}), 500

# ─── Endpoint de controle para o widget ────────────────────────────────────────
@app.route('/api/control', methods=['POST'])
def api_control():
    data = request.json or {}
    action = data.get('action')
    value  = data.get('value')

    try:
        with device_lock:
            dev = get_device()
            if action == 'power_on':
                dev.set_value(int(DP_MAP['switch']), True)
            elif action == 'power_off':
                dev.set_value(int(DP_MAP['switch']), False)
            elif action == 'set_temp':
                # value é temperatura em graus inteiros, multiplicamos por 10
                temp = int(float(value) * 10)
                dev.set_value(int(DP_MAP['temp_set']), temp)
            elif action == 'set_mode':
                # value: 'cold' | 'hot' | 'wind' | 'wet' | 'auto'
                dev.set_value(int(DP_MAP['mode']), value)
            elif action == 'set_fan':
                # value: 'auto' | 'low' | 'mid' | 'high'
                dev.set_value(int(DP_MAP['fan_speed']), value)
            elif action == 'toggle_eco':
                dev.set_value(int(DP_MAP['mode_eco']), bool(value))
            elif action == 'toggle_light':
                dev.set_value(int(DP_MAP['light']), bool(value))
            elif action == 'toggle_sleep':
                dev.set_value(int(DP_MAP['sleep']), bool(value))
            elif action == 'toggle_swing':
                dev.set_value(int(DP_MAP['swing']), bool(value))
            elif action == 'toggle_lock':
                dev.set_value(int(DP_MAP['lock']), bool(value))
            elif action == 'toggle_health':
                dev.set_value(int(DP_MAP['health']), bool(value))
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
        result = get_device().set_value(dp, value)
        print(f"Enviado dp={dp} value={value} -> resposta: {result}")
        return jsonify({"status": "success", "dp": dp, "value": value})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/status')
def status():
    try:
        data = get_device().status()
        return jsonify(data.get('dps', {}))
    except Exception as e:
        print(f"Erro ao ler status: {e}")
        return jsonify({}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8456, debug=False)