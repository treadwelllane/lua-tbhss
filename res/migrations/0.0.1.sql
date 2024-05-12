create table words_model (
  id integer primary key,
  name varchar not null unique,
  loaded boolean not null default false,
  dimensions integer not null
);

create table words (
  id integer not null, -- 1-N for each word (not a primary key)
  id_words_model integer references words_model (id) on delete cascade,
  name varchar not null,
  embedding blob not null,
  primary key (id_words_model, id),
  unique (id_words_model, name),
  unique (id_words_model, id)
);

create table clusters_model (
  id integer primary key,
  id_words_model integer references words_model (id) on delete cascade,
  name varchar not null unique,
  clusters integer not null,
  clustered boolean not null default false,
  iterations integer not null default 0
);

create table clusters (
  id integer not null, -- 1-N for each cluster (not a primary key)
  id_clusters_model integer references clusters_model (id) on delete cascade,
  id_words integer references words (id) on delete cascade,
  similarity real not null,
  primary key (id_clusters_model, id_words, id)
);

create table bitmaps_model (
  id integer primary key,
  id_clusters_model integer references clusters_model (id) on delete cascade,
  params json not null,
  name varchar not null unique,
  created boolean not null default false
);

create table bitmaps (
  id_bitmaps_model integer references bitmaps_model (id) on delete cascade,
  id_words integer references words (id) on delete cascade,
  bitmap blob not null,
  primary key (id_bitmaps_model, id_words)
);

create table sentences_model (
  id integer primary key,
  name varchar not null unique,
  loaded boolean not null default false
);

create table sentences (
  id integer not null, -- 1-N for each sentence (not a primary key)
  id_sentences_model integer references sentences_model (id) on delete cascade,
  label varchar not null,
  a varchar not null,
  b blob not null,
  primary key (id_sentences_model, id)
);

create table encoder_model (
  id integer primary key,
  id_bitmaps_model integer references bitmaps_model (id) on delete cascade,
  params json not null,
  name varchar not null unique,
  trained boolean not null default false,
  model blob
);
