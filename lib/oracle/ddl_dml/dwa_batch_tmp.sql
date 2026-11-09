-- Keys of the open batch. Emptied on commit.
create global temporary table dwa_batch_tmp (
    pk_1            varchar2(255) not null,
    pk_2            varchar2(255),
    pk_3            varchar2(255)
) on commit delete rows;

comment on table dwa_batch_tmp is
    'Keys of the open batch.';
