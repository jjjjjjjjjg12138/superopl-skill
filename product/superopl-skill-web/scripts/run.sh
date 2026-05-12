#!/usr/bin/env bash
set -euo pipefail

INTENT=""
CONFIG_PATH="$(dirname "$0")/../config/skill_config.json"
OUTPUT="table"
ENTITY="tasks"
QUERY=""
UPCOMING_DAYS=7
MAX_OUTPUT_CHARS=8000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --intent) INTENT="$2"; shift 2;;
    --config-path) CONFIG_PATH="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    --entity) ENTITY="$2"; shift 2;;
    --query) QUERY="$2"; shift 2;;
    --upcoming-days) UPCOMING_DAYS="$2"; shift 2;;
    --max-output-chars) MAX_OUTPUT_CHARS="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ -z "$INTENT" ]]; then
  echo '{"status":"error","errors":[{"code":"validation_error","message":"--intent is required"}]}'
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "{\"status\":\"error\",\"errors\":[{\"code\":\"validation_error\",\"message\":\"Config file not found: $CONFIG_PATH\"}]}"
  exit 1
fi

API_KEY=$(python - <<'PY' "$CONFIG_PATH"
import json,sys
p=sys.argv[1]
obj=json.load(open(p,'r',encoding='utf-8'))
act=obj.get('active_profile','default')
pro=obj.get('profiles',{}).get(act,{})
print(pro.get('api_key',''))
PY
)
OPL_ID=$(python - <<'PY' "$CONFIG_PATH"
import json,sys
p=sys.argv[1]
obj=json.load(open(p,'r',encoding='utf-8'))
act=obj.get('active_profile','default')
pro=obj.get('profiles',{}).get(act,{})
print(pro.get('opl_id',''))
PY
)
BASE_URL=$(python - <<'PY' "$CONFIG_PATH"
import json,sys
p=sys.argv[1]
obj=json.load(open(p,'r',encoding='utf-8'))
act=obj.get('active_profile','default')
pro=obj.get('profiles',{}).get(act,{})
print(pro.get('base_url','https://rb-superopl.emea.bosch.com'))
PY
)

if [[ -z "$API_KEY" || -z "$OPL_ID" ]]; then
  echo '{"status":"error","errors":[{"code":"validation_error","message":"api_key/opl_id missing in config"}]}'
  exit 1
fi

case "$INTENT" in
  read)
    if [[ "$ENTITY" == "tasks" ]]; then
      URL="$BASE_URL/api/opls/$OPL_ID/tasks/?key=$API_KEY"
      curl -sS "$URL"
    else
      URL="$BASE_URL/api/opls/$OPL_ID/?key=$API_KEY"
      curl -sS "$URL"
    fi
    ;;
  track)
    URL="$BASE_URL/api/opls/$OPL_ID/tasks/?key=$API_KEY"
    RAW=$(curl -sS "$URL")
    python - <<'PY' "$RAW"
import json,sys,datetime
raw=sys.argv[1]
obj=json.loads(raw)
data=obj.get('data',obj)
items=list(data.values()) if isinstance(data,dict) else data
now=datetime.date.today()
open_items=[]
overdue=[]
for t in items:
    st=str(t.get('status',''))
    if st!='0':
        continue
    open_items.append(t)
    d=t.get('endDateActualISO') or (t.get('endDateActual') or {}).get('date') or t.get('endDate')
    if d:
        ds=str(d)[:10]
        try:
            dd=datetime.date.fromisoformat(ds)
            if dd<now:
                overdue.append(t)
        except Exception:
            pass
print(json.dumps({"status":"ok","data":{"open":len(open_items),"overdue":len(overdue)}}))
PY
    ;;
  analyze)
    if [[ -z "$QUERY" ]]; then
      echo '{"status":"error","errors":[{"code":"validation_error","message":"--query is required for analyze"}]}'
      exit 1
    fi
    URL="$BASE_URL/api/opls/$OPL_ID/tasks/?key=$API_KEY"
    RAW=$(curl -sS "$URL")
    python - <<'PY' "$RAW" "$QUERY"
import json,sys,re
raw=sys.argv[1]; q=sys.argv[2].lower()
obj=json.loads(raw)
data=obj.get('data',obj)
items=list(data.values()) if isinstance(data,dict) else data
hits=[]
for t in items:
    subj=str(t.get('subject',''))
    desc=str(t.get('description',''))
    if q in subj.lower() or q in desc.lower():
        hits.append({"taskId":t.get('taskId') or t.get('id'),"subject":subj,"description":desc[:400]})
print(json.dumps({"status":"ok","data":{"query":q,"hits":hits[:10],"note":"description evidence included"}},ensure_ascii=False))
PY
    ;;
  *)
    echo "{\"status\":\"error\",\"errors\":[{\"code\":\"validation_error\",\"message\":\"unsupported intent: $INTENT\"}]}"
    exit 1
    ;;
esac
