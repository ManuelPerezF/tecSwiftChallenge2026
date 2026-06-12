#!/bin/bash
# Smoke test de las features Lumina (waiting_list, reapertura, eventos, tags).
# Requiere el servidor corriendo: npm run dev  (puerto 3000 por defecto)
set -e
BASE="${BASE:-http://localhost:3000/api}"
J='Content-Type: application/json'

echo "── 1. Registro organizer ──"
ORG=$(curl -s -X POST "$BASE/auth/register" -H "$J" -d '{
  "email":"org-smoke@kuidar.app","password":"demo123","name":"Centro Comunitario",
  "role":"organizer","familyName":"Centro Comunitario Del Valle"}')
ORG_TOKEN=$(echo "$ORG" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
echo "organizer token: ${ORG_TOKEN:0:8}…"

echo "── 2. Crear evento comunitario (3 cupos) ──"
EVENT=$(curl -s -X POST "$BASE/requests" -H "$J" -H "Authorization: Bearer $ORG_TOKEN" -d '{
  "activityType":"compania","details":"Jornada de acompañamiento",
  "scheduledDate":"2026-06-20T10:00:00Z","isUrgent":false,
  "lat":19.38,"lng":-99.16,"isCommunityEvent":true,"maxHelpersRequired":3}')
EVENT_ID=$(echo "$EVENT" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
echo "evento: $EVENT_ID"

echo "── 3. Listar eventos ──"
curl -s "$BASE/requests/events" -H "Authorization: Bearer $ORG_TOKEN" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(f"{len(d)} evento(s), cupo {d[0][\"activeHelpers\"]}/{d[0][\"maxHelpersRequired\"]}")'

echo "── 4. Login familia demo + registro como asistente ──"
FAM=$(curl -s -X POST "$BASE/auth/login" -H "$J" -d '{"email":"familia@kuidar.app","password":"demo123"}')
FAM_TOKEN=$(echo "$FAM" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -X POST "$BASE/requests/$EVENT_ID/attendees" -H "Authorization: Bearer $FAM_TOKEN" | head -c 120; echo
curl -s "$BASE/requests/$EVENT_ID/attendees" -H "Authorization: Bearer $FAM_TOKEN" \
  | python3 -c 'import sys,json;print(f"{len(json.load(sys.stdin))} asistente(s)")'

echo "── 5. Login becario demo + tags ──"
STU=$(curl -s -X POST "$BASE/auth/login" -H "$J" -d '{"email":"becario@kuidar.app","password":"demo123"}')
STU_TOKEN=$(echo "$STU" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -X PUT "$BASE/students/me/tags" -H "$J" -H "Authorization: Bearer $STU_TOKEN" \
  -d '{"tags":["cocina","dominó","plantas"]}'; echo

echo "── 6. Flujo waiting_list ──"
REQ=$(curl -s -X POST "$BASE/requests" -H "$J" -H "Authorization: Bearer $FAM_TOKEN" -d '{
  "activityType":"mandados","details":"Smoke test","scheduledDate":"2026-06-21T10:00:00Z",
  "isUrgent":false,"lat":19.38,"lng":-99.16}')
REQ_ID=$(echo "$REQ" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
APP=$(curl -s -X POST "$BASE/requests/$REQ_ID/applications" -H "$J" -H "Authorization: Bearer $STU_TOKEN" -d '{"message":"yo voy"}')
APP_ID=$(echo "$APP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
ASSIGN=$(curl -s -X POST "$BASE/applications/$APP_ID/approve" -H "Authorization: Bearer $FAM_TOKEN")
ASSIGN_ID=$(echo "$ASSIGN" | python3 -c 'import sys,json;print(json.load(sys.stdin)["assignmentId"])')
echo "assignment: $ASSIGN_ID"

echo "── 7. Cancelar → request se reabre y postulación queda cancelled_by_helper ──"
curl -s -X POST "$BASE/assignments/$ASSIGN_ID/cancelar" -H "Authorization: Bearer $FAM_TOKEN" \
  | python3 -c 'import sys,json;print("assignment status:",json.load(sys.stdin)["status"])'
curl -s "$BASE/requests/$REQ_ID" -H "Authorization: Bearer $FAM_TOKEN" \
  | python3 -c 'import sys,json;print("request status:",json.load(sys.stdin)["status"],"(esperado: open)")'
curl -s "$BASE/requests/$REQ_ID/applications" -H "Authorization: Bearer $FAM_TOKEN" \
  | python3 -c 'import sys,json;print("application status:",json.load(sys.stdin)[0]["status"],"(esperado: cancelled_by_helper)")'

echo "✅ Smoke test completo"
