#!/bin/sh
# Run the suite in an Oracle container. Host does not need sqlplus.
set -eu
cd "$(dirname "$0")/../.."

container="${ORACLE_CONTAINER:-dwa-oracle}"
connect="${ORACLE_CONNECT:-test/test_pass@//localhost:1521/FREEPDB1}"
ora_user="${connect%%/*}"
ora_net="${connect#*@}"
ora_pdb="${ora_net##*/}"

docker exec "$container" mkdir -p /tmp/dwa/lib/oracle /tmp/dwa/tests/oracle /tmp/dwa/demo/oracle
docker cp lib/oracle/. "$container:/tmp/dwa/lib/oracle"
docker cp tests/oracle/. "$container:/tmp/dwa/tests/oracle"
docker cp demo/oracle/. "$container:/tmp/dwa/demo/oracle"
# Grant DBMS_LOCK as SYS.
if [ -n "${ORACLE_SYS_CONNECT:-}" ]; then
    docker exec -w /tmp/dwa "$container" \
        sqlplus -S "$ORACLE_SYS_CONNECT" @lib/oracle/grant_lock.sql "$ora_user"
else
    printf 'alter session set container = %s;\n@lib/oracle/grant_lock.sql %s\n' \
        "$ora_pdb" "$ora_user" |
        docker exec -i -w /tmp/dwa "$container" sqlplus -S / as sysdba
fi
docker exec -w /tmp/dwa "$container" \
    sqlplus -S "$connect" @lib/oracle/rollback.sql
docker exec -w /tmp/dwa "$container" \
    sqlplus -S "$connect" @lib/oracle/deploy.sql
docker exec -w /tmp/dwa "$container" \
    sqlplus -S "$connect" @tests/oracle/run.sql
