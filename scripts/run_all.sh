#!/usr/bin/env bash
# Build the database and run every analysis. Usage: ./scripts/run_all.sh [database_name]
set -euo pipefail
DB=${1:-vendor_ops}
cd "$(dirname "$0")/.."
createdb "$DB" 2>/dev/null || true
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f sql/00_schema.sql
for f in sql/0[1-9]*.sql; do
  name=$(basename "$f" .sql)
  psql -q -v ON_ERROR_STOP=1 -d "$DB" --csv -f "$f" > "results/$name.csv"
  echo "ran $name -> results/$name.csv"
done
