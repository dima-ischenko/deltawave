create or replace package pkg_dwa is

  -- Starts a run. Exclusive lock on (owner, target, slice) until finalize.
  procedure initialize(
      p_target_table    varchar2,
      p_owner           varchar2 default null,
      p_data_slice      varchar2 default 'all',
      p_lookback_hours  number   default 0,
      p_debug           boolean  default false,
      p_log_table       boolean  default false
  );

  -- Inserts changed keys into dwa_keys_tmp. p_sql must contain :since and return pk_1, watermark.
  procedure capture_delta(
      p_source_table    varchar2,
      p_sql             varchar2,
      p_owner           varchar2 default null,
      p_lookback_hours  number default null
  );

  -- Optional. Then next_batch / refresh / finish_batch. Without it, refresh reads dwa_keys_tmp.
  procedure prepare_batches(
      p_batch_size    number  default 5000,
      p_commit_batch  boolean default true
  );

  -- True while a batch is open in dwa_batch_tmp.
  function next_batch return boolean;

  -- Marks the open batch complete. Pass p_merged from the caller's refresh.
  procedure finish_batch(p_merged number default null);

  -- Writes watermarks, releases the lock. Does not commit.
  procedure finalize;

  -- Installed library version.
  function version return varchar2;

end pkg_dwa;