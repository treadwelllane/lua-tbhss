create table sentence_pos (
  id integer not null, -- 1-N for each pos (not a primary key)
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  pos varchar not null,
  primary key (id_triplets_model, id),
  unique (id_triplets_model, pos)
);

