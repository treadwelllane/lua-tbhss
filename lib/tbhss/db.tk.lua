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
local str = require("santoku.string")
local arr = require("santoku.array")
local it = require("santoku.iter")
local cjson = require("cjson")
local sqlite = require("lsqlite3")
local open = sqlite.open

return function (db_file)

  local db = sql(open(db_file))

  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")

  -- luacheck: push ignore
  migrate(db, <%
    return serialize(tabulate(map(function (fp)
      return basename(fp), readfile(fp)
    end, files("res/migrations")))), false
  %>)
  -- luacheck: pop

  local M = { db = db }

  M.add_words_model = db.inserter([[
    insert into words_model (name, total, dimensions, embeddings)
    values (?, ?, ?, ?)
  ]])

  M.add_sentences_model = db.inserter([[
    insert into sentences_model
    (name, topic_segments, position_segments,
     position_dimensions, position_buckets, saturation,
     length_normalization)
    values
    (:name, :topic_segments, :position_segments,
     :position_dimensions, :position_buckets, :saturation,
     :length_normalization)
  ]])

  M.add_clusters_model = db.inserter([[
    insert into clusters_model (name, id_words_model, clusters)
    values (?, ?, ?)
  ]])

  local encode_encoder_model = function (inserter)
    return function (n, e, p)
      return inserter(n, e, cjson.encode(p))
    end
  end

  local decode_encoder_model = function (getter)
    return function (...)
      local model = getter(...)
      if model and model.params then
        model.params = cjson.decode(model.params)
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

  M.add_encoder_model = encode_encoder_model(db.inserter([[
    insert into encoder_model (name, id_sentences_model, params)
    values (?, ?, ?)
  ]]))

  M.set_words_loaded = db.runner([[
    update words_model
    set loaded = true
    where id = ?
  ]])

  M.set_sentences_loaded = db.runner([[
    update sentences_model
    set loaded = true
    where id = ?
  ]])

  M.set_sentences_clusters = db.runner([[
    update sentences_model
    set id_clusters_model = :id_clusters_model,
        min_set = :min_set,
        max_set = :max_set,
        min_similarity = :min_similarity,
        include_raw = :include_raw
    where id = :id_sentences_model
  ]])

  M.set_encoder_trained = db.runner([[
    update encoder_model
    set trained = true, model = ?2
    where id = ?1
  ]])

  M.get_encoder = decode_encoder(db.getter([[
    select model from encoder_model where id = ?1
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

  M.get_sentences_model_by_name = db.getter([[
    select *
    from sentences_model
    where name = ?
  ]])

  M.get_word_embeddings = db.getter([[
    select embeddings
    from words_model
    where id = ?1
  ]], "embeddings")

  M.get_clusters_model_by_name = db.getter([[
    select *
    from clusters_model
    where name = ?
  ]])

  M.get_encoder_model_by_name = decode_encoder_model(db.getter([[
    select *
    from encoder_model
    where name = ?
  ]]))

  M.get_words_model_by_id = db.getter([[
    select id, name, loaded, total, dimensions
    from words_model
    where id = ?
  ]])

  M.get_total_words = db.getter([[
    select total
    from words_model
    where id = ?
  ]], "total")

  M.get_sentences_model_by_id = db.getter([[
    select *
    from sentences_model
    where id = ?
  ]])

  M.get_clusters_model_by_id = db.getter([[
    select *
    from clusters_model
    where id = ?
  ]])

  M.get_encoder_model_by_id = decode_encoder_model(db.getter([[
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
    insert into sentences (id, id_sentences_model, sentence)
    values (?, ?, ?)
  ]])

  M.add_sentence_fingerprint = db.runner([[
    update sentences
    set fingerprint = ?3
    where id_sentences_model = ?1
    and id = ?2
  ]])

  M.get_sentence_id = db.getter([[
    select id
    from sentences
    where id_sentences_model = ?1
    and sentence = ?2
  ]], "id")

  M.create_sentences_fts5 = function (id_model)
    local sql = str.interp([[
      create virtual table sentences_%d#(1)_fts using fts5 (sentence, tokenize = "unicode61 tokenchars '-'");
      create virtual table sentences_%d#(1)_fts_aux using fts5vocab (sentences_%d#(1)_fts, 'row');
    ]], { id_model })
    db.exec(sql)
  end

  M.sentence_fts_adder = function (id_model)
    return db.inserter(str.interp([[
      insert into sentences_%d#(1)_fts (sentence)
      values (?)
    ]], { id_model }))
  end

  M.add_sentence_pair = db.inserter([[
    insert into sentence_pairs (id_sentences_model, id_a, id_b, label)
    values (?, ?, ?, ?) on conflict (id_sentences_model, id_a, id_b) do nothing
  ]])

  local get_sentence_word_id = db.getter([[
    select id
    from sentence_words
    where id_sentences_model = ?1
    and word = ?2
  ]], "id")

  local add_sentence_word = db.inserter([[
    insert into sentence_words (id_sentences_model, id, word)
    values (?, ?, ?)
  ]])

  M.get_sentence_word_max = db.getter([[
    select max(id) as max
    from sentence_words
    where id_sentences_model = ?1
  ]], "max")

  M.add_sentence_word = function (id_model, word)
    local id = get_sentence_word_id(id_model, word)
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
    set tokens = ?3
    where id_sentences_model = ?1
    and id = ?2
  ]])

  local has_sentence_tokens = db.getter([[
    select 1 as ok
    from sentences
    where id_sentences_model = ?1
    and id = ?2
    and tokens is not null
  ]], "ok")

  M.set_sentence_tokens = function (idm, id, ws, keep)
    if not keep or not has_sentence_tokens(idm, id) then
      set_sentence_tokens(idm, id, cjson.encode(ws))
    end
  end

  local get_sentences = db.iter([[
    select * from
    sentences
    where id_sentences_model = ?1
    order by id asc
  ]])

  M.get_sentences = function (...)
    return it.map(function (s)
      s.tokens = cjson.decode(s.tokens)
      return s
    end, get_sentences(...))
  end

  M.sentence_token_scores_getter = function (id_sentences_model)

    local fts = arr.concat({ "sentences_", id_sentences_model, "_fts" })
    local ftsvocab = arr.concat({ "sentences_", id_sentences_model, "_fts_aux" })

    local total_docs = db.getter(str.interp([[
      select count(*) as total_docs
      from %fts
    ]], { fts = fts }), "total_docs")()

    local average_length = db.getter(str.interp([[
      select avg(length(sentence)) as avgdl
      from %fts
    ]], { fts = fts }), "avgdl")()

    local get_weights = db.all(str.interp([[
      select distinct j.value as token,
             x.cnt *
             (log(?5 - x.cnt + 0.5) - log(x.cnt + 0.5) + 1) *
             (?3 + 1) / (x.cnt + ?3 * (1 - ?4 + ?4 *
               (length(sf.sentence) / ?6)))
               as weight
      from json_each(s.tokens) j
      join sentences s on s.id_sentences_model = ?1 and s.id = ?2
      join %fts sf on sf.rowid = x.doc
      join %ftsvocab x on cast(x.term as integer) = j.value
    ]], { fts = fts, ftsvocab = ftsvocab }))

    return function (id_sentence, saturation, length_normalization)
      local out = {}
      local weights = get_weights(
        id_sentences_model,
        id_sentence,
        saturation,
        length_normalization,
        total_docs,
        average_length)
      for i = 1, #weights do
        local w = weights[i]
        out[w.token] = w.weight
      end
      return out
    end

  end

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
      sentences_model sm,
      sentence_words sw
    where
      wm.id = ?1 and
      sm.name = ?2 and
      wm.id = w.id_words_model and
      sm.id = sw.id_sentences_model and
      sw.word = w.word
    order by
      w.id asc
  ]], "id")

  M.get_clustered_words = db.iter([[
    select distinct(id_words) from clusters where id_clusters_model = ?
  ]])

  M.get_nearest_clusters = db.iter([[

    select * from (
      select c.id, c.similarity
      from sentences_model sm,
           clusters_model cm,
           words_model wm,
           clusters c,
           words w,
           sentence_words sw
      where sm.id = ?1
      and cm.id = sm.id_clusters_model
      and wm.id = cm.id_words_model
      and c.id_clusters_model = cm.id
      and c.id_words = w.id
      and w.id_words_model = wm.id
      and sw.id_sentences_model = sm.id
      and sw.word = w.word
      and sw.id = ?2
      order by c.similarity desc
      limit ?3
    )

    union all

    select * from (
      select c.id, c.similarity
      from sentences_model sm,
           clusters_model cm,
           words_model wm,
           clusters c,
           words w,
           sentence_words sw
      where sm.id = ?1
      and cm.id = sm.id_clusters_model
      and wm.id = cm.id_words_model
      and c.id_clusters_model = cm.id
      and c.id_words = w.id
      and w.id_words_model = wm.id
      and sw.id_sentences_model = sm.id
      and sw.word = w.word
      and sw.id = ?2
      and c.similarity >= ?5
      order by c.similarity desc
      limit ?4 - ?3 offset ?3
    )

  ]])

  M.get_sentence_triplets = db.all([[
    select distinct
      anchor_sent.sentence as anchor,
      anchor_sent.fingerprint as anchor_fingerprint,
      positive_sent.sentence as positive,
      positive_sent.fingerprint as positive_fingerprint,
      negative_sent.sentence as negative,
      negative_sent.fingerprint as negative_fingerprint
    from
      sentence_pairs as anchor
    join
      sentence_pairs as positive
      on anchor.id_a = positive.id_a
      and positive.id_sentences_model = anchor.id_sentences_model
      and positive.label = 'entailment'
    join
      sentence_pairs as negative
      on anchor.id_a = negative.id_a
      and negative.id_sentences_model = anchor.id_sentences_model
      and (negative.label = 'neutral' or negative.label = 'contradiction')
    join sentences anchor_sent
      on anchor.id_a = anchor_sent.id
      and anchor_sent.id_sentences_model = anchor.id_sentences_model
    join sentences positive_sent
      on positive.id_b = positive_sent.id
      and positive_sent.id_sentences_model = positive.id_sentences_model
    join sentences negative_sent
      on negative.id_b = negative_sent.id
      and negative_sent.id_sentences_model = negative.id_sentences_model
    where
      anchor.label in ('entailment', 'neutral', 'contradiction')
      and anchor.id_sentences_model = ?1
      and anchor.id_b != positive.id_b
      and anchor.id_b != negative.id_b
      and positive.id_b != negative.id_b
    order by random()
    limit coalesce(?2, -1)
  ]])

  return M

end
