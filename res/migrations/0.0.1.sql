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

create table triplets_model (
  id integer primary key,
  name varchar not null unique,
  bits integer,
  args json,
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
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  sentence varchar not null,
  tokens json,
  length integer,
  positions json,
  similarities json,
  fingerprint blob,
  primary key (id_triplets_model, id)
);

create table sentences_tf (
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  id_sentence integer not null,
  token integer not null,
  freq integer not null,
  unique (id_triplets_model, id_sentence, token)
);

create table sentences_df (
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  token integer not null,
  freq integer not null,
  unique (id_triplets_model, token)
);

create table sentence_triplets (
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  id_anchor integer,
  id_positive integer,
  id_negative integer,
  unique (id_triplets_model, id_anchor, id_positive, id_negative)
);

create table sentence_words (
  id integer not null, -- 1-N for each word (not a primary key)
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  word varchar not null,
  primary key (id_triplets_model, id),
  unique (id_triplets_model, word)
);

create table encoder_model (
  id integer primary key,
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  args json not null,
  name varchar not null unique,
  trained boolean not null default false,
  model blob
);

create index words_word
  on words (word);

create index sentences_id_triplets_model_sentence
  on sentences (id_triplets_model, sentence);

create index clusters_id_clusters_model_similarity
  on clusters (id_clusters_model, similarity);
