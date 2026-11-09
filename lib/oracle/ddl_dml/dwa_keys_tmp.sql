-- Keys of the current run. Survive commit until the session ends.
create global temporary table dwa_keys_tmp (
    source_owner    varchar2(128) not null,
    source_table    varchar2(128) not null,
    pk_1            varchar2(255) not null,
    pk_2            varchar2(255),
    pk_3            varchar2(255),
    watermark       date          not null,
    batch_no        number,
    batch_done      number(1)     default 0 not null,
    constraint ck_dwa_keys_tmp_done check (batch_done in (0, 1))
) on commit preserve rows;

create index idx_dwa_keys_tmp_batch
    on dwa_keys_tmp (batch_no, batch_done);

comment on table dwa_keys_tmp is
    'Keys of the current run. Target and slice live in the session.';
comment on column dwa_keys_tmp.source_owner is
    'Schema of the source.';
comment on column dwa_keys_tmp.source_table is
    'Source that produced this key.';
comment on column dwa_keys_tmp.pk_1 is
    'First part of the business key.';
comment on column dwa_keys_tmp.watermark is
    'Source value of this key.';
comment on column dwa_keys_tmp.batch_no is
    'Batch of a distinct key. Null when batches are not used.';
comment on column dwa_keys_tmp.batch_done is
    '1 after finish_batch.';
