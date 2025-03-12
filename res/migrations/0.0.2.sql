create table autoencoder_model (
  id integer primary key,
  id_triplets_model integer not null references triplets_model (id) on delete cascade,
  args json not null,
  name varchar not null unique,
  trained boolean not null default false,
  model blob
);
