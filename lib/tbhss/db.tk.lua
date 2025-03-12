<%
  fs = require("santoku.fs")
  files = fs.files
  basename = fs.basename

  iter = require("santoku.iter")
  tabulate = iter.tabulate
  map = iter.map

  serialize = require("santoku.serialize")
%>

local sql = require("santoku.sqlite")
local migrate = require("santoku.sqlite.migrate")
local tm = require("santoku.tsetlin")
local fs = require("santoku.fs")
local varg = require("santoku.varg")
local cjson = require("cjson")
local sqlite = require("lsqlite3")
local open = sqlite.open

return function (db_file, skip_init)

  local db = sql(open(db_file))

  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")
  db.exec("pragma busy_timeout = 30000")

  if not skip_init then

    -- luacheck: push ignore
    migrate(db, <%
      return serialize(tabulate(map(function (fp)
        return basename(fp), readfile(fp)
      end, files("res/migrations")))), false
    %>)
    -- luacheck: pop

  end

  local M = { db = db, file = db_file }

  local encode_tables = function (inserter)
    return function (...)
      return inserter(varg.map(function (t)
        if type(t) == "table" then
          return cjson.encode(t)
        else
          return t
        end
      end, ...))
    end
  end

  local decode_args = function (getter)
    return function (...)
      local model = getter(...)
      if model and model.args then
        model.args = cjson.decode(model.args)
        return model
      end
    end
  end

  local decode_encoder = function (getter)
    return function (...)
      local model = getter(...)
      -- TODO: read directly from sqlite without temporary file
      local fp = fs.tmpname()
      fs.writefile(fp, model)
      local t = tm.load(fp)
      fs.rm(fp)
      return t
    end
  end

  local decode_autoencoder = function (getter)
    return function (...)
      local model = getter(...)
      -- TODO: read directly from sqlite without temporary file
      local fp = fs.tmpname()
      fs.writefile(fp, model)
      local t = tm.load(fp)
      fs.rm(fp)
      return t
    end
  end

  M.add_words_model = db.inserter([[
    insert into words_model (name, total, dimensions, embeddings)
    values (?1, ?2, ?3, ?4)
  ]])

  M.add_triplets_model = encode_tables(db.inserter([[
    insert into triplets_model (name, args) values (?1, ?2)
  ]]))

  M.add_clusters_model = encode_tables(db.inserter([[
    insert into clusters_model (name, id_words_model, args)
    values (?1, ?2, ?3)
  ]]))

  M.add_encoder_model = encode_tables(db.inserter([[
    insert into encoder_model (name, id_triplets_model, args)
    values (?, ?, ?)
  ]]))

  M.add_autoencoder_model = encode_tables(db.inserter([[
    insert into autoencoder_model (name, id_triplets_model, args)
    values (?, ?, ?)
  ]]))

  M.get_num_clusters = db.getter([[
    select count(distinct id) as n from clusters where id_clusters_model = ?1
  ]], "n")

  M.set_words_loaded = db.runner([[
    update words_model
    set loaded = true
    where id = ?
  ]])

  M.set_triplets_loaded = db.runner([[
    update triplets_model
    set loaded = true, bits = ?2
    where id = ?1
  ]])

  M.set_triplets_args = encode_tables(db.runner([[
    update triplets_model
    set args = ?2
    where id = ?1
  ]]))

  M.set_encoder_trained = db.runner([[
    update encoder_model
    set trained = true, model = ?2
    where id = ?1
  ]])

  M.set_autoencoder_trained = db.runner([[
    update autoencoder_model
    set trained = true, model = ?2
    where id = ?1
  ]])

  M.get_encoder = decode_encoder(db.getter([[
    select model from encoder_model where id = ?1
  ]], "model"))

  M.get_autoencoder = decode_autoencoder(db.getter([[
    select model from autoencoder_model where id = ?1
  ]], "model"))

  M.set_words_clustered = db.runner([[
    update clusters_model
    set clustered = true
    where id = ?1
  ]])

  M.get_words_model_by_name = db.getter([[
    select id, name, loaded, total, dimensions
    from words_model
    where name = ?
  ]])

  M.get_triplets_model_by_name = decode_args(db.getter([[
    select *
    from triplets_model
    where name = ?
  ]]))

  M.get_word_embeddings = db.getter([[
    select embeddings
    from words_model
    where id = ?1
  ]], "embeddings")

  M.get_clusters_model_by_name = decode_args(db.getter([[
    select *
    from clusters_model
    where name = ?
  ]]))

  M.get_encoder_model_by_name = decode_args(db.getter([[
    select *
    from encoder_model
    where name = ?
  ]]))

  M.get_autoencoder_model_by_name = decode_args(db.getter([[
    select *
    from autoencoder_model
    where name = ?
  ]]))

  M.get_words_model_by_id = db.getter([[
    select id, name, loaded, total, dimensions
    from words_model
    where id = ?
  ]])

  M.get_total_unique_words = db.getter([[
    select count(*) as count
    from sentence_words
    where id_triplets_model = ?1
  ]], "count")

  M.get_total_words = db.getter([[
    select total
    from words_model
    where id = ?
  ]], "total")

  M.get_triplets_model_by_id = decode_args(db.getter([[
    select *
    from triplets_model
    where id = ?
  ]]))

  M.get_clusters_model_by_id = decode_args(db.getter([[
    select *
    from clusters_model
    where id = ?
  ]]))

  M.get_autoencoder_model_by_id = decode_args(db.getter([[
    select *
    from autoencoder_model
    where id = ?
  ]]))

  M.get_encoder_model_by_id = decode_args(db.getter([[
    select *
    from encoder_model
    where id = ?
  ]]))

  M.add_word = db.inserter([[
    insert into words (id, id_words_model, word)
    values (?, ?, ?)
    on conflict (id_words_model, word) do nothing
  ]])

  M.add_sentence = db.inserter([[
    insert into sentences (id, id_triplets_model, sentence)
    values (?, ?, ?)
  ]])

  M.add_sentence_with_fingerprint = db.inserter([[
    insert into sentences (id, id_triplets_model, sentence, fingerprint)
    values (?, ?, ?, ?)
  ]])

  M.add_sentence_fingerprint = db.runner([[
    update sentences
    set fingerprint = ?3
    where id_triplets_model = ?1
    and id = ?2
  ]])

  M.set_sentence_tf = db.runner([[
    insert into sentences_tf (id_triplets_model, id_sentence, token, freq)
    select s.id_triplets_model, s.id as id_sentence, j.value as token, count(*) as freq
    from sentences s
    join json_each(s.tokens) j on 1 = 1
    where s.id_triplets_model = ?1
    group by s.id, j.value
  ]])

  M.set_sentence_df = db.runner([[
    insert into sentences_df (id_triplets_model, token, freq)
    select s.id_triplets_model, j.value as token, count(distinct s.id) as freq
    from sentences s
    join json_each(s.tokens) j on 1 = 1
    where s.id_triplets_model = ?1
    group by j.value
  ]]);

  M.get_sentence_id = db.getter([[
    select id
    from sentences
    where id_triplets_model = ?1
    and sentence = ?2
  ]], "id")

  M.add_sentence_triplet = db.inserter([[
    insert into sentence_triplets (id_triplets_model, id_anchor, id_positive, id_negative)
    values (?, ?, ?, ?) on conflict (id_triplets_model, id_anchor, id_positive, id_negative) do nothing
  ]])

  M.get_sentence_word_id = db.getter([[
    select id
    from sentence_words
    where id_triplets_model = ?1
    and word = ?2
  ]], "id")

  local add_sentence_word = db.inserter([[
    insert into sentence_words (id_triplets_model, id, word)
    values (?, ?, ?)
  ]])

  M.get_sentence_word_max = db.getter([[
    select max(id) as max
    from sentence_words
    where id_triplets_model = ?1
  ]], "max")

  M.add_sentence_word = function (id_model, word)
    local id = M.get_sentence_word_id(id_model, word)
    if id then
      return id
    else
      local max = M.get_sentence_word_max(id_model)
      id = (max or 0) + 1
      add_sentence_word(id_model, id, word)
      return id
    end
  end

  local set_sentence_tokens = db.runner([[
    update sentences
    set tokens = ?3, positions = ?4, similarities = ?5, length = ?6
    where id_triplets_model = ?1
    and id = ?2
  ]])

  local has_sentence_tokens = db.getter([[
    select 1 as ok
    from sentences
    where id_triplets_model = ?1
    and id = ?2
    and tokens is not null
  ]], "ok")

  M.set_sentence_tokens = function (idm, id, ws, ps, ss, len, keep)
    if not keep or not has_sentence_tokens(idm, id) then
      set_sentence_tokens(idm, id,
        cjson.encode(ws),
        cjson.encode(ps),
        cjson.encode(ss),
        len)
    end
  end

  local get_sentences = db.all([[
    select * from
    sentences
    where id_triplets_model = ?1
    order by id asc
  ]])

  M.get_sentences = function (...)
    local ss = get_sentences(...)
    for i = 1, #ss do
      local s = ss[i]
      s.tokens = cjson.decode(s.tokens)
      s.positions = cjson.decode(s.positions)
      s.similarities = cjson.decode(s.similarities)
    end
    return ss
  end

  M.get_total_docs = db.getter([[
    select count(*) as total
    from sentences where id_triplets_model = ?1
  ]], "total")

  M.get_average_doc_length = db.getter([[
    select avg(length) as avgdl
    from sentences where id_triplets_model = ?1
  ]], "avgdl")

  M.set_word_cluster_similarity = db.inserter([[
    insert into clusters (id_clusters_model, id_words, id, similarity)
    values (?, ?, ?, ?)
  ]])

  M.get_word_id = db.getter([[
    select id from words
    where id_words_model = ?1
    and word = ?2
  ]], "id")

  M.get_clusters = db.iter([[
    select c.id_words, c.id, c.similarity
    from clusters c
    where c.id_clusters_model = ?
  ]])

  M.delete_words_model_by_name = db.runner([[
    delete from words_model
    where name = ?
  ]])

  M.delete_clusters_model_by_name = db.runner([[
    delete from clusters_model
    where name = ?
  ]])

  M.get_all_filtered_words = db.all([[
    select
      w.id
    from
      words_model wm,
      words w,
      triplets_model sm,
      sentence_words sw
    where
      wm.id = ?1 and
      sm.name = ?2 and
      wm.id = w.id_words_model and
      sm.id = sw.id_triplets_model and
      sw.word = w.word
    order by
      w.id asc
  ]], "id")

  M.get_clustered_words = db.iter([[
    select distinct(id_words) from clusters where id_clusters_model = ?
  ]])

  local get_nearest_clusters = db.all([[
    select
      sw.id as token,
      c.id as cluster,
      c.similarity
    from
      triplets_model sm,
      sentence_words sw,
      clusters c,
      words w
    where
      sm.id = ?1 and
      sw.id_triplets_model = sm.id and
      c.id_clusters_model = json_extract(sm.args, '$.id_clusters_model') and
      w.id = c.id_words and
      sw.word = w.word
  ]])

  M.get_nearest_clusters = function (...)
    local ts = get_nearest_clusters(...)
    local r = {}
    for i = 1, #ts do
      local t = ts[i]
      local cs = r[t.token] or {}
      cs[#cs + 1] = t
      r[t.token] = cs
    end
    return r
  end

  local get_dfs = db.all([[
    select token, freq
    from sentences_df
    where id_triplets_model = ?1
  ]])

  M.get_dfs = function (...)
    local dfs = get_dfs(...)
    local r = {}
    for i = 1, #dfs do
      local t = dfs[i]
      r[t.token] = t.freq
    end
    return r
  end

  local get_tfs = db.all([[
    select id_sentence as sentence, token, freq
    from sentences_tf
    where id_triplets_model = ?1
  ]])

  M.get_tfs = function (...)
    local tfs = get_tfs(...)
    local r = {}
    for i = 1, #tfs do
      local t = tfs[i]
      local tf = r[t.sentence] or {}
      r[t.sentence] = tf
      tf[t.token] = t.freq
    end
    return r
  end

  M.get_sentence_fingerprints = db.all([[
    select
      s.id,
      s.fingerprint,
      s.sentence
    from
      sentences s
    where
      s.id_triplets_model = ?1
    order by random()
    limit coalesce(?2, -1)
  ]])

  M.copy_triplets = db.runner([[
    insert into sentence_triplets (id_triplets_model, id_anchor, id_positive, id_negative)
    select ?2, id_anchor, id_negative, id_positive
    from sentence_triplets where id_triplets_model = ?1
  ]])

  M.get_sentence_triplets = db.all([[
    select distinct
      anchors.sentence as anchor,
      anchors.fingerprint as anchor_fingerprint,
      positives.sentence as positive,
      positives.fingerprint as positive_fingerprint,
      negatives.sentence as negative,
      negatives.fingerprint as negative_fingerprint
    from
      sentence_triplets triplets
    join
      sentences anchors on
        triplets.id_anchor = anchors.id and
        triplets.id_triplets_model = anchors.id_triplets_model and
        anchors.fingerprint is not null
    join
      sentences positives on
        triplets.id_positive = positives.id and
        triplets.id_triplets_model = positives.id_triplets_model and
        positives.fingerprint is not null
    join
      sentences negatives on
        triplets.id_negative = negatives.id and
        triplets.id_triplets_model = negatives.id_triplets_model and
        negatives.fingerprint is not null
    where
      triplets.id_triplets_model = ?1
    order by random()
    limit coalesce(?2, -1)
  ]])

  return M

end
