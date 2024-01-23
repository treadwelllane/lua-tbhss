create table models (
  id integer primary key,
  tag varchar not null unique,
  words_loaded boolean not null default false,
  dimensions integer not null
);

create table clusterings (
  id integer primary key,
  id_model integer references models (id) on delete cascade,
  clusters integer not null,
  words_clustered boolean not null default false,
  iterations integer not null default 0,
  unique (id_model, clusters)
);

create table words (
  id integer not null,
  id_model integer references models (id) on delete cascade,
  name varchar not null,
  vector blob not null,
  unique (id_model, name),
  primary key (id, id_model)
);

create table clusters (
  id_clustering integer references clusterings (id) on delete cascade,
  id_word integer references words (id) on delete cascade,
  id_cluster integer not null,
  similarity real not null,
  primary key (id_cluster, id_word)
);
