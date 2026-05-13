#!/usr/bin/env bash
set -euo pipefail

INTENT=""
CONFIG_PATH="$(dirname "$0")/../config/skill_config.json"
OUTPUT="table"
ENTITY="tasks"
QUERY=""
KEYWORDS=""
TYPE=""
RESPONSIBLE=""
STATUS_FILTER=""
TOP=50
UPCOMING_DAYS=7
MAX_OUTPUT_CHARS=8000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --intent) INTENT="$2"; shift 2;;
    --config-path) CONFIG_PATH="$2"; shift 2;;
    --output) OUTPUT="$2"; shift 2;;
    --entity) ENTITY="$2"; shift 2;;
    --query) QUERY="$2"; shift 2;;
    --keywords) KEYWORDS="$2"; shift 2;;
    --type) TYPE="$2"; shift 2;;
    --responsible) RESPONSIBLE="$2"; shift 2;;
    --status) STATUS_FILTER="$2"; shift 2;;
    --top) TOP="$2"; shift 2;;
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
  query)
    URL="$BASE_URL/api/opls/$OPL_ID/tasks/?key=$API_KEY"
    RAW=$(curl -sS "$URL")
    python - <<PY "$RAW" "$KEYWORDS" "$TYPE" "$RESPONSIBLE" "$STATUS_FILTER" "$TOP"
import json,sys,re
raw=sys.argv[1]; kw=sys.argv[2].lower(); typ=sys.argv[3].lower()
resp=sys.argv[4].lower(); st=sys.argv[5]; top=int(sys.argv[6]) if sys.argv[6] else 50
obj=json.loads(raw)
data=obj.get('data',obj)
items=list(data.values()) if isinstance(data,dict) else data
type_map={'task':1,'decision':2,'information':3,'review':4,'problem':6,'measure':7}
status_map={'open':'0','closed':'1'}
results=[]
for t in items:
    subj=str(t.get('subject',''))
    desc=str(t.get('description',''))
    text=(subj+' '+desc).lower()
    if kw and kw not in text: continue
    if typ:
        tc=type_map.get(typ,None)
        if tc and str(t.get('type',''))!=str(tc): continue
    if resp and resp not in str(t.get('responsible','')).lower(): continue
    if st:
        sc=status_map.get(st,st)
        if str(t.get('status',''))!=sc: continue
    results.append({'taskId':t.get('taskId') or t.get('id'),'subject':subj,'type':t.get('type'),'status':t.get('status'),'responsible':t.get('responsible'),'owner':t.get('owner'),'endDate':str(t.get('endDateActualISO',''))[:10],'description':desc[:300]})
    if len(results)>=top: break
print(json.dumps({'status':'ok','data':{'matched':len(results),'items':results}},ensure_ascii=False))
PY
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
    python - <<PY "$RAW" "$QUERY" "$TOP"
import json,sys,re
raw=sys.argv[1]; q=sys.argv[2].lower(); top=int(sys.argv[3]) if sys.argv[3] else 10
obj=json.loads(raw)
data=obj.get('data',obj)
items=list(data.values()) if isinstance(data,dict) else data
tokens=[t for t in q.split() if len(t)>=2]
def score(t):
    text=(str(t.get('subject',''))+' '+str(t.get('description',''))).lower()
    return sum(1 for tk in tokens if tk in text)
scored=sorted([t for t in items if score(t)>0],key=score,reverse=True)
type_name={1:'task',2:'decision',3:'information',4:'review',6:'problem',7:'measure'}
freq={}
for t in items:
    if str(t.get('type',''))=='6':
        for tk in tokens:
            if tk in str(t.get('subject','')).lower():
                freq[tk]=freq.get(tk,0)+1
problems=[t for t in scored if str(t.get('type',''))=='6'][:top]
measures=[t for t in scored if str(t.get('type',''))=='7'][:top]
hits=[{'taskId':t.get('taskId') or t.get('id'),'subject':str(t.get('subject','')),'type':type_name.get(int(t.get('type',0)),'unknown'),'status':'open' if str(t.get('status',''))=='0' else 'closed','responsible':str(t.get('responsible','')),'endDate':str(t.get('endDateActualISO',''))[:10],'description':str(t.get('description',''))[:400]} for t in (problems+measures)[:top]]
print(json.dumps({'status':'ok','data':{'query':q,'total':len(items),'matched':len(scored),'keyword_frequency':freq,'hits':hits,'note':'description evidence included'}},ensure_ascii=False))
PY
    ;;
  *)
    echo "{\"status\":\"error\",\"errors\":[{\"code\":\"validation_error\",\"message\":\"unsupported intent: $INTENT\"}]}"
    exit 1
    ;;
esac
