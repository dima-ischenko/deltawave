# Deltawave (DWA)

Incremental load of a target table on Oracle and PostgreSQL. dwa stores a watermark per source, captures the keys that moved, and leaves the refresh SQL to you. A watermark never moves backwards.

- Oracle: [deploy](lib/oracle/deploy.md), [call](lib/oracle/README.md)
- PostgreSQL and Greenplum: [deploy](lib/postgres/deploy.md), [call](lib/postgres/README.md)

Try it from [`demo/`](demo/README.md).

## API

On Oracle the entry point is `pkg_dwa`. On PostgreSQL the same methods are functions with a `dwa_` prefix (`dwa_initialize`, `dwa_capture_delta`, ...) in the install schema (`perform` from PL/pgSQL).

A run is `initialize` -> `capture_delta` per source -> refresh SQL -> `finalize`. Batches are optional: `prepare_batches`, then `next_batch` / refresh / `finish_batch`.

### initialize(p_target_table, p_owner, p_data_slice, p_lookback_hours, p_debug, p_log_table)

Starts a run and clears `dwa_keys_tmp`. Exclusive session lock on `(owner, target_table, data_slice)` until `finalize` or disconnect. The target must exist and be selectable.

| Parameter | Required | Default | Effect |
| --- | --- | --- | --- |
| `p_target_table` | yes | - | Unqualified target being loaded. |
| `p_owner` | no | current schema | Schema of the target. |
| `p_data_slice` | no | `'all'` | Independent watermark slice of this target. |
| `p_lookback_hours` | no | `0` | Hours subtracted from the stored watermark when binding `:since`. Not written to `dwa_watermark`. |
| `p_debug` | no | `false` | Extra diagnostic output on capture and finalize. |
| `p_log_table` | no | `false` | Write each step to `dwa_log`. On Oracle the insert is autonomous. |

A second session that calls `initialize` for the same triple gets `DWA-20021` / `-20021`. A missing or inaccessible target gets `DWA-20022` / `-20022`.

### capture_delta(p_source_table, p_sql, p_owner, p_lookback_hours)

Inserts changed keys into `dwa_keys_tmp`. The source must exist and be selectable. Watermarks are stored per source owner and name.

| Parameter | Required | Default | Effect |
| --- | --- | --- | --- |
| `p_source_table` | yes | - | Unqualified source name stored with the watermark. |
| `p_sql` | yes | - | Must return `pk_1` and `watermark`. `pk_2` and `pk_3` are optional. Must contain `:since`. `:data_slice` is optional. |
| `p_owner` | no | current schema | Schema of the source. |
| `p_lookback_hours` | no | `null` | Lookback for this source. `null` uses the value from `initialize`. |

`:since` is the stored watermark minus the lookback. With no stored row the bound is `2000-01-01`.

### prepare_batches(p_batch_size [, p_commit_batch])

Numbers distinct keys. Skip it to refresh every key from `dwa_keys_tmp` in one statement.

| Parameter | Required | Default | Effect |
| --- | --- | --- | --- |
| `p_batch_size` | no | `5000` | Distinct keys per batch. |
| `p_commit_batch` | no | `true` | Oracle only. When true, `finish_batch` commits that batch. PostgreSQL never commits; commit after `finish_batch` yourself. |

### next_batch() -> boolean

Loads the next unfinished batch into `dwa_batch_tmp`. Returns true while a batch is open, false when none remain. Call `prepare_batches` first. Do not commit between `next_batch` and `finish_batch`.

### finish_batch([p_merged])

Marks the open batch done.

| Parameter | Required | Default | Effect |
| --- | --- | --- | --- |
| `p_merged` | no | `null` | Row count of the refresh, for the log. Pass `sql%rowcount` / `GET DIAGNOSTICS ROW_COUNT` from the caller. |

### finalize()

Writes, for each source, the greatest captured watermark. Never moves a watermark backwards. Does not commit. Errors if a batch is still unfinished. Commit after it to store the watermark.

After a failure, repeat from `initialize`. The refresh SQL must be idempotent.

Without batches the refresh reads `dwa_keys_tmp`. With batches the refresh reads `dwa_batch_tmp`.

## Tables

Same names on Oracle and PostgreSQL.

`dwa_watermark` is permanent. One row per `(target_owner, target_table, data_slice, source_owner, source_table)`.

| Column | Meaning |
| --- | --- |
| `target_owner`, `target_table`, `data_slice`, `source_owner`, `source_table` | Grain of the row |
| `watermark` | Greatest source value fully applied |
| `updated_at` | Time of the last `finalize` write |

`dwa_keys_tmp` holds every key of the current run. Rows survive a commit and last until the session ends.

| Column | Meaning |
| --- | --- |
| `source_owner`, `source_table` | Source that produced this key |
| `pk_1`, `pk_2`, `pk_3` | Business key of the target row |
| `watermark` | Source value of this key |
| `batch_no`, `batch_done` | Set by `prepare_batches`. `batch_done` becomes `1` after `finish_batch` |

`dwa_batch_tmp` holds `pk_1`, `pk_2`, `pk_3` of the open batch. A commit empties it.

`dwa_log` is permanent. Rows are appended only when `initialize` is called with `p_log_table` true.

| Column | Meaning |
| --- | --- |
| `logged_at` | Time of the step |
| `proc_name` | `dwa_initialize`, `dwa_capture_delta`, ... (Oracle: `pkg_dwa.initialize`) |
| `target_owner`, `target_table`, `data_slice`, `batch_no` | Session state at that step |
| `log_rows` | Row count of the step |
| `message` | Same text as the notice / `dbms_output` line |

## Data slices

Use a named `p_data_slice` when the same target is loaded in independent slices. Each slice has its own watermark. Filter capture SQL with `:data_slice`. In refresh SQL use the same literal you passed to `initialize`.

```sql
pkg_dwa.initialize(p_target_table => 'customer_metrics', p_data_slice => 'fr', p_lookback_hours => 2);

pkg_dwa.capture_delta(p_source_table => 'orders', p_sql => q'[
    select customer_id as pk_1,
           max(updated_at) as watermark
    from orders
    where country_code = :data_slice
      and updated_at > :since
    group by customer_id
]');
```

On PostgreSQL the same call is `dwa_initialize`. Cross-schema sources pass `p_owner`:

```sql
dwa_initialize(p_target_table => 'customer_metrics', p_owner => 'analytics');
dwa_capture_delta(p_source_table => 'orders', p_sql => '...', p_owner => 'sales');
```

## Hard deletes

Not supported. A physical `DELETE` never reaches `dwa_keys_tmp`. To drop a target row, keep a source row whose watermark still moves (flag, tombstone, audit) and delete it in the refresh SQL.

## Soft deletes

Set the tombstone and a watermark together (`deleted_at`) and return that column as `watermark`. The refresh deletes the target row. Clearing the flag puts the row back if capture still selects the key.

## Rolling keys

Open rows (`closed_at` / `date_to` is null) must be selected even when their watermark is older than `:since`:

```sql
where updated_at > :since
   or closed_at is null
```

Return the row's real source watermark. `finalize` never moves a stored watermark backwards, so open keys do not pull it back.

## Tests

```bash
docker compose -f tests/docker/docker-compose.yml up --wait
ORACLE_CONTAINER=dwa-oracle \
ORACLE_CONNECT=test/test_pass@//localhost:1521/FREEPDB1 \
PG_CONTAINER=dwa-postgres \
make test
```

`make` without those variables uses containers named `oracle` and `postgres`. The Oracle image is [gvenzl/oracle-free](https://github.com/gvenzl/oci-oracle-free); the first start takes several minutes.
