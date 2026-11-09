# Defaults match a local database. Override for tests/docker (dwa-oracle / dwa-postgres).

ORACLE_CONTAINER ?= oracle
ORACLE_CONNECT ?= test/test_pass@//localhost:1521/test_db
export ORACLE_CONTAINER ORACLE_CONNECT

PG_CONTAINER ?= postgres
PGUSER ?= test_user
PGPASSWORD ?= test_pass
PGDATABASE ?= test_db
export PG_CONTAINER PGUSER PGPASSWORD PGDATABASE

.PHONY: test-oracle test-postgres test

test: test-oracle test-postgres

test-oracle:
	tests/oracle/run.sh

test-postgres:
	tests/postgres/run.sh
