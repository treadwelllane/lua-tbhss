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
  clusters integer not null,
  clustered boolean not null default false
);

create table sentences_model (
  id integer primary key,
  name varchar not null unique,
  id_clusters_model integer references clusters_model (id) on delete cascade,
  min_set integer,
  max_set integer,
  min_similarity real,
  include_raw boolean,
  segments integer not null,
  dimensions integer not null,
  buckets integer not null,
  saturation integer not null,
  length_normalization integer not null,
  loaded boolean not null default false
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

create table sentences (
  id integer not null, -- 1-N for each sentence (not a primary key)
  id_sentences_model integer not null references sentences_model (id) on delete cascade,
  sentence varchar not null,
  tokens json,
  positions json,
  fingerprint blob,
  primary key (id_sentences_model, id)
);

create table sentences_tf (
  id_sentences_model integer not null references sentences_model (id) on delete cascade,
  id_sentence integer not null,
  token integer not null,
  freq integer not null,
  unique (id_sentences_model, id_sentence, token)
);

create table sentences_df (
  id_sentences_model integer not null references sentences_model (id) on delete cascade,
  token integer not null,
  freq integer not null,
  unique (id_sentences_model, token)
);

create table sentence_pairs (
  id_sentences_model integer not null references sentences_model (id) on delete cascade,
  label varchar,
  id_a integer,
  id_b integer,
  unique (id_sentences_model, id_a, id_b)
);

create table sentence_words (
  id integer not null, -- 1-N for each word (not a primary key)
  id_sentences_model integer not null references sentences_model (id) on delete cascade,
  word varchar not null,
  primary key (id_sentences_model, id),
  unique (id_sentences_model, word)
);

create table encoder_model (
  id integer primary key,
  id_sentences_model integer not null references sentences_model (id) on delete cascade,
  params json not null,
  name varchar not null unique,
  trained boolean not null default false,
  model blob
);

create index sentences_id_sentences_model_sentence
  on sentences (id_sentences_model, sentence);

create index clusters_id_clusters_model_similarity
  on clusters (id_clusters_model, similarity);
