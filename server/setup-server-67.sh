#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SYPNOSE — Server 67 Runbook (Wave 1 + Wave 3.2 del plan sypnose-global-100626)
# Ejecutar como root (o sudo) en el server 67 (Contabo, Ubuntu).
# Idempotente: se puede re-ejecutar. Cada paso verifica antes de seguir.
#
# QUE HACE:
#   1. Verifica que sypnose-unified esta vivo en 127.0.0.1:18900
#   2. Instala nginx + certbot y publica https://mcp.sypnose.cloud/mcp (y /sse)
#   3. Genera NUEVA API key, la anade al servicio (key vieja sigue valida 7 dias)
#   4. Cierra el 18900 publico en UFW (solo localhost + nginx 443)
#   5. Configura ANTHROPIC_AUTH_TOKEN en el daemon claw (workers sonnet-4-6)
#   6. Verificacion final completa
#
# REQUISITO PREVIO (manual, 1 minuto — Cloudflare):
#   Crear registro A:  mcp.sypnose.cloud -> IP publica del server 67
#   Modo "DNS only" (nube gris) hasta que certbot emita el certificado;
#   despues se puede activar proxy naranja si se quiere.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

DOMAIN="mcp.sypnose.cloud"
BACKEND="127.0.0.1:18900"
SVC="sypnose-unified"
SVC_DIR="/home/shared/sypnose-mcp-unified"
GRACE_DAYS=7

ok(){ echo "  [+] $*"; }
err(){ echo "  [x] $*" >&2; }

echo "── PASO 1: backend vivo ──────────────────────────────────"
systemctl is-active --quiet "$SVC" || { err "$SVC caido — arrancando"; systemctl start "$SVC"; sleep 2; }
systemctl is-active --quiet "$SVC" && ok "$SVC activo" || { err "$SVC no arranca. journalctl -u $SVC -n 50"; exit 1; }
ss -tlnp | grep -q ":18900" && ok "puerto 18900 escuchando" || { err "18900 no escucha"; exit 1; }

OLD_KEY="$(grep -roP 'Bearer \K[a-f0-9]{64}' "$SVC_DIR" 2>/dev/null | head -1 || true)"
HTTP_LOCAL=$(curl -s -m 8 -o /dev/null -w "%{http_code}" -X POST "http://$BACKEND/mcp" \
  ${OLD_KEY:+-H "Authorization: Bearer $OLD_KEY"} -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
[[ "$HTTP_LOCAL" =~ ^(200|401|403)$ ]] && ok "backend responde local (HTTP $HTTP_LOCAL)" || { err "backend HTTP $HTTP_LOCAL"; exit 1; }

echo "── PASO 2: nginx + TLS para $DOMAIN ─────────────────────"
getent hosts "$DOMAIN" >/dev/null || { err "$DOMAIN no resuelve. Crea el registro A en Cloudflare primero (DNS only) y re-ejecuta."; exit 1; }
apt-get install -y -qq nginx certbot python3-certbot-nginx >/dev/null

cat > /etc/nginx/sites-available/$DOMAIN << NGINX
server {
    listen 80;
    server_name $DOMAIN;

    location /mcp {
        proxy_pass http://$BACKEND/mcp;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }
    location /sse {
        proxy_pass http://$BACKEND/sse;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Host \$host;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 24h;
        chunked_transfer_encoding off;
    }
    location / { return 404; }
}
NGINX
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
nginx -t && systemctl reload nginx && ok "nginx proxy configurado"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@sypnose.com --redirect && ok "TLS emitido (Let's Encrypt, auto-renueva)"

echo "── PASO 3: rotacion de key (con gracia de $GRACE_DAYS dias) ──"
NEW_KEY="$(openssl rand -hex 32)"
# El servicio debe aceptar AMBAS keys durante la gracia. Implementacion segun index.js:
# si usa una sola env var, anadir soporte multi-key: SYPNOSE_KEYS="vieja,nueva".
if grep -q "SYPNOSE_KEYS" "$SVC_DIR/index.js" 2>/dev/null; then
    ok "index.js ya soporta multi-key"
else
    echo "  [!] index.js valida una sola key. Editar la comprobacion del Bearer a:"
    echo '      const keys = (process.env.SYPNOSE_KEYS || "").split(",");'
    echo '      if (!keys.includes(token)) return 401;'
    echo "  [!] Hacerlo AHORA (es 1 linea) y re-ejecutar este paso."
fi
mkdir -p /etc/systemd/system/$SVC.service.d
cat > /etc/systemd/system/$SVC.service.d/keys.conf << EOF
[Service]
Environment="SYPNOSE_KEYS=${OLD_KEY:+$OLD_KEY,}$NEW_KEY"
EOF
systemctl daemon-reload && systemctl restart "$SVC" && ok "servicio reiniciado con key nueva (+vieja en gracia)"
echo ""
echo "  ╔══════════════════════════════════════════════════════╗"
echo "    NUEVA KEY (guardar en KB, NUNCA en el repo):"
echo "    $NEW_KEY"
echo "  ╚══════════════════════════════════════════════════════╝"
echo "  Recordatorio: en $GRACE_DAYS dias quitar la key vieja de keys.conf y restart."
echo "  kb_save key=sypnose-key-rotation-$(date +%d%m%y) category=config project=servidor-infra"

echo "── PASO 4: firewall — 18900 solo interno ────────────────"
if command -v ufw &>/dev/null; then
    ufw allow 443/tcp >/dev/null; ufw allow 80/tcp >/dev/null
    ufw deny 18900/tcp >/dev/null && ok "UFW: 18900 cerrado al publico, 443/80 abiertos"
else
    err "ufw no instalado — cerrar 18900 con iptables o el firewall de Contabo"
fi

echo "── PASO 5: ANTHROPIC_AUTH_TOKEN para workers sonnet-4-6 ──"
# El daemon claw necesita el token para despachar claude-sonnet-4-6.
# El token se saca de la cuenta Anthropic de Carlos (Console -> API keys) — NO se genera aqui.
CLAW_ENV="/etc/claw/daemon.env"
if [[ -f "$CLAW_ENV" ]] && grep -q "ANTHROPIC_AUTH_TOKEN=." "$CLAW_ENV"; then
    ok "claw daemon ya tiene ANTHROPIC_AUTH_TOKEN"
else
    echo "  [!] FALTA: anadir a $CLAW_ENV (o al unit del daemon claw):"
    echo "      ANTHROPIC_AUTH_TOKEN=<api key de console.anthropic.com>"
    echo "      y reiniciar el daemon. Pedir la key a Carlos — PARADA que requiere su input."
fi

echo "── PASO 6: verificacion final ────────────────────────────"
sleep 2
H=$(curl -s -m 10 -o /dev/null -w "%{http_code}" -X POST "https://$DOMAIN/mcp" \
  -H "Authorization: Bearer $NEW_KEY" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
[[ "$H" == "200" ]] && ok "https://$DOMAIN/mcp -> 200 con key nueva" || err "HTTPS dio $H — revisar"
TOOLS=$(curl -s -m 10 -X POST "https://$DOMAIN/mcp" -H "Authorization: Bearer $NEW_KEY" \
  -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | grep -o '"name"' | wc -l)
echo "  [i] tools expuestas: $TOOLS (esperado: 14)"
echo ""
echo "  DONE. Siguiente: git push del repo parcheado + kb_save del resultado."
