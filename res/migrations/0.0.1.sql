create table embeddings_model (
  id integer primary key,
  name varchar not null unique,
  loaded boolean not null default false,
  dimensions integer not null
);

create table embeddings (
  id_embeddings_model integer references embeddings_model (id) on delete cascade,
  id integer not null,
  name varchar not null,
  embedding blob not null,
  primary key (id_embeddings_model, id),
  unique (id_embeddings_model, name)
);

create table clusters_model (
  id integer primary key,
  id_embeddings_model integer references embeddings_model (id) on delete cascade,
  name varchar not null unique,
  clusters integer not null,
  clustered boolean not null default false,
  iterations integer not null default 0
);

create table clusters (
  id_clusters_model integer references clusters_model (id) on delete cascade,
  id_embedding integer references embeddings (id) on delete cascade,
  id integer not null,
  similarity real not null,
  primary key (id_clusters_model, id_embedding, id)
);

create table encoder_model (
  id integer primary key,
  id_embeddings_model integer references embeddings_model (id) on delete cascade,
  params json not null,
  name varchar not null unique,
  created boolean not null default false,
  model blob
);

create table bitmaps_model (
  id integer primary key,
  model_type varchar not null,
  model_ref integer not null,
  model_params json not null,
  name varchar not null unique,
  created boolean not null default false
);

create table bitmaps (
  id_bitmaps_model integer references bitmaps_model (id) on delete cascade,
  id_embedding integer references embeddings (id) on delete cascade,
  bitmap blob not null,
  primary key (id_bitmaps_model, id_embedding)
);
