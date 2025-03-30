create table words_model (
  id integer primary key,
  name varchar not null unique,
  loaded boolean not null default false,
  total integer not null,
  dimensions integer not null,
  embeddings blob not null
);

create table clusters_model (
  id integer primary key,
  id_words_model integer not null references words_model (id) on delete cascade,
  name varchar not null unique,
  args json,
  clustered boolean not null default false
);

create table words (
  id integer not null, -- 1-N for each word (not a primary key)
  id_words_model integer not null references words_model (id) on delete cascade,
  word varchar not null,
  primary key (id_words_model, id),
  unique (id_words_model, word),
  unique (id_words_model, id)
);

create table clusters (
  id integer not null, -- 1-N for each cluster (not a primary key)
  id_clusters_model integer not null references clusters_model (id) on delete cascade,
  id_words integer not null references words (id) on delete cascade,
  similarity real not null,
  primary key (id_clusters_model, id_words, id)
);

create index words_word
  on words (word);

create index clusters_id_clusters_model_similarity
  on clusters (id_clusters_model, similarity);

create table modeler (
  id integer primary key,
  name text unique,
  visible integer not null,
  hidden integer not null,
  tokenizer text not null,
  compressor text not null
);

create table classifier (
  id integer primary key,
  name text unique,
  modeler text not null,
  labels json not null,
  classifier text not null
);

create table encoder (
  id integer primary key,
  name text unique,
  modeler text not null,
  encoder text not null
);
