#!/usr/bin/env bash
# 把 Aurora Glass 皮肤应用到 Jellyfin / AList（方案 B：只用原生钩子）
# 用法:
#   JELLYFIN_API_KEY=xxx ALIST_ADMIN_PASSWORD=yyy ./apply-skins.sh
# 可选: JELLYFIN_URL=http://127.0.0.1:8096  ALIST_URL=http://172.18.0.2:5244
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
JF_URL="${JELLYFIN_URL:-http://127.0.0.1:8096}"
AL_URL="${ALIST_URL:-172.18.0.2:5244}"

if [ -n "${JELLYFIN_API_KEY:-}" ]; then
  python3 - "$JF_URL" "$JELLYFIN_API_KEY" "$HERE/skins/jellyfin.css" <<'PY'
import json,sys,urllib.request
url,key,css_path=sys.argv[1],sys.argv[2],sys.argv[3]
body=json.dumps({"SplashscreenEnabled":False,"CustomCss":open(css_path).read()}).encode()
req=urllib.request.Request(url+"/System/Configuration/branding",data=body,method="POST",
  headers={"Authorization":f'MediaBrowser Token="{key}"',"Content-Type":"application/json"})
print("jellyfin:",urllib.request.urlopen(req,timeout=15).status)
PY
else
  echo "跳过 Jellyfin（未设置 JELLYFIN_API_KEY）"
fi

if [ -n "${ALIST_ADMIN_PASSWORD:-}" ]; then
  python3 - "$AL_URL" "$ALIST_ADMIN_PASSWORD" "$HERE/skins/alist-head.html" <<'PY'
import json,sys,urllib.request
base,pw,head_path=sys.argv[1],sys.argv[2],sys.argv[3]
def post(path,payload,token=None):
    h={"Content-Type":"application/json"}
    if token: h["Authorization"]=token
    req=urllib.request.Request(f"http://{base}{path}",data=json.dumps(payload).encode(),method="POST",headers=h)
    return json.loads(urllib.request.urlopen(req,timeout=15).read())
tok=post("/files/api/auth/login",{"username":"admin","password":pw})["data"]["token"]
head=open(head_path).read()
# 注意: save 接口要传数组
r=post("/files/api/admin/setting/save",[{"key":"main_color","value":"#6ea8ff"},{"key":"customize_head","value":head}],tok)
print("alist:",r.get("message"))
PY
else
  echo "跳过 AList（未设置 ALIST_ADMIN_PASSWORD）"
fi
