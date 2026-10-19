#!/bin/bash
# Roda os testes SQL dos desafios no Supabase do Carburante, numa transação que
# termina em ROLLBACK (nada fica no banco).
#   supabase/tests/run.sh            → testa o que já está aplicado
#   supabase/tests/run.sh --migrate  → aplica antes, na mesma transação, as
#                                      colunas novas de fuel_logs e o
#                                      challenges.sql (testa a migração sem gravar)
# Precisa de SUPABASE_ACCESS_TOKEN (Management API). Imprime "ok" ou o erro.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
project="ptcjnqnueazqpkinvgwr"

sql="$(cat "$here/tests/challenges_test.sql")"
if [[ "${1:-}" == "--migrate" ]]; then
    migration="$(grep -E '^alter table public\.fuel_logs add column if not exists (odometer_photo_source|challenge_photo_url)' "$here/schema.sql")
$(cat "$here/challenges.sql")"
    # Entra logo depois do "begin;" do teste.
    sql="$(python3 -c 'import sys; t, m = sys.argv[1], sys.argv[2]; print(t.replace("begin;\n", "begin;\n" + m + "\n", 1))' "$sql" "$migration")"
fi

payload="$(python3 -c 'import json, sys; print(json.dumps({"query": sys.stdin.read()}))' <<< "$sql")"
curl -s "https://api.supabase.com/v1/projects/$project/database/query" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$payload"
echo
