#!/bin/sh
# Run the suite in a Postgres container. Host does not need psql.
set -eu
cd "$(dirname "$0")/../.."

container="${PG_CONTAINER:-postgres}"
user="${PGUSER:-test_user}"
password="${PGPASSWORD:-test_pass}"
database="${PGDATABASE:-test_db}"

docker exec "$container" mkdir -p /tmp/dwa/lib/postgres /tmp/dwa/tests/postgres /tmp/dwa/demo/postgres
docker cp lib/postgres/. "$container:/tmp/dwa/lib/postgres"
docker cp tests/postgres/. "$container:/tmp/dwa/tests/postgres"
docker cp demo/postgres/. "$container:/tmp/dwa/demo/postgres"
docker exec -w /tmp/dwa -e PGPASSWORD="$password" "$container" \
    psql -U "$user" -d "$database" -v ON_ERROR_STOP=1 \
    -f tests/postgres/run.sql
