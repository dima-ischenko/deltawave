------- functions
drop function if exists :"dwa_schema".dwa_finalize();
drop function if exists :"dwa_schema".dwa_finish_batch(bigint);
drop function if exists :"dwa_schema".dwa_next_batch();
drop function if exists :"dwa_schema".dwa_prepare_batches(numeric);
drop function if exists :"dwa_schema".dwa_capture_delta(text, text, text, numeric);
drop function if exists :"dwa_schema".dwa_initialize(text, text, text, numeric, boolean, boolean);
drop function if exists :"dwa_schema".dwa_version();
drop function if exists :"dwa_schema"._dwa_write_log(text, numeric, text);
drop function if exists :"dwa_schema"._dwa_debug();
drop function if exists :"dwa_schema"._dwa_batch_total();
drop function if exists :"dwa_schema"._dwa_unassigned();
drop function if exists :"dwa_schema"._dwa_unfinished();
drop function if exists :"dwa_schema"._dwa_qualify_relation(text, text, text);
drop function if exists :"dwa_schema"._dwa_assert_relation(text, text);
drop function if exists :"dwa_schema"._dwa_norm_ident(text, text);
drop function if exists :"dwa_schema"._dwa_release_run_lock(text, text, text);
drop function if exists :"dwa_schema"._dwa_acquire_run_lock(text, text, text);
drop function if exists :"dwa_schema"._dwa_ensure_temp();
