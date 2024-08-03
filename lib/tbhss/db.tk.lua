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

  M.add_words_model = db.inserter([[
    insert into words_model (name, total, dimensions, embeddings)
    values (?1, ?2, ?3, ?4)
  ]])

  M.add_sentences_model = encode_tables(db.inserter([[
    insert into sentences_model (name, args) values (?1, ?2)
  ]]))

  M.add_clusters_model = encode_tables(db.inserter([[
    insert into clusters_model (name, id_words_model, args)
    values (?1, ?2, ?3)
  ]]))

  M.add_encoder_model = encode_tables(db.inserter([[
    insert into encoder_model (name, id_sentences_model, args)
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

  M.set_sentences_args = encode_tables(db.runner([[
    update sentences_model
    set args = ?2
    where id = ?1
  ]]))

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

  M.get_sentences_model_by_name = decode_args(db.getter([[
    select *
    from sentences_model
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

  M.get_sentences_model_by_id = decode_args(db.getter([[
    select *
    from sentences_model
    where id = ?
  ]]))

  M.get_clusters_model_by_id = decode_args(db.getter([[
    select *
    from clusters_model
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
    insert into sentences (id, id_sentences_model, sentence)
    values (?, ?, ?)
  ]])

  M.add_sentence_fingerprint = db.runner([[
    update sentences
    set fingerprint = ?3
    where id_sentences_model = ?1
    and id = ?2
  ]])

  M.set_sentence_tf = db.runner([[
    insert into sentences_tf (id_sentences_model, id_sentence, token, freq)
    select s.id_sentences_model, s.id as id_sentence, j.value as token, count(*) as freq
    from sentences s
    join json_each(s.tokens) j on 1 = 1
    where s.id_sentences_model = ?1
    group by s.id, j.value
  ]])

  M.set_sentence_df = db.runner([[
    insert into sentences_df (id_sentences_model, token, freq)
    select s.id_sentences_model, j.value as token, count(distinct s.id) as freq
    from sentences s
    join json_each(s.tokens) j on 1 = 1
    where s.id_sentences_model = ?1
    group by j.value
  ]]);

  M.get_sentence_id = db.getter([[
    select id
    from sentences
    where id_sentences_model = ?1
    and sentence = ?2
  ]], "id")

  M.add_sentence_pair = db.inserter([[
    insert into sentence_pairs (id_sentences_model, id_a, id_b, label)
    values (?, ?, ?, ?) on conflict (id_sentences_model, id_a, id_b) do nothing
  ]])

  M.get_sentence_word_id = db.getter([[
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
    where id_sentences_model = ?1
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
    from sentences where id_sentences_model = ?1
  ]], "total")

  M.get_average_doc_length = db.getter([[
    select avg(length) as avgdl
    from sentences where id_sentences_model = ?1
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

  local get_nearest_clusters = db.all([[

    with ranked_clusters as (
      select
        c.id_words as token,
        c.id as cluster,
        c.similarity,
        row_number() over (
          partition by c.id_words order by c.similarity desc
        ) as rank
      from
        clusters c
      where
        c.id_clusters_model = ?1
    )
    select token, cluster, similarity
    from ranked_clusters
    where rank <= ?2
    union all
    select token, cluster, similarity
    from ranked_clusters
    where rank > ?2 and rank <= ?3 and similarity >= ?4

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
    where id_sentences_model = ?1
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
    where id_sentences_model = ?1
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
      and anchor_sent.fingerprint is not null
      and positive_sent.fingerprint is not null
      and negative_sent.fingerprint is not null
    limit coalesce(?2, -1)
  ]])

  return M

end
