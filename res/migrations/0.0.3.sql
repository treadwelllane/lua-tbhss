alter table triplets_model add column type text;
update triplets_model set type = 'triplets';

create table classifier_model (
  id integer primary key,
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  args json not null,
  name varchar not null unique,
  trained boolean not null default false,
  model blob
);

create table sentence_pairs (
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  id_a integer,
  id_b integer,
  label text,
  unique (id_triplets_model, id_a, id_b)
);
