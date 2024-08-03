local words = {}

for w in io.lines(arg[1]) do
  words[w] = true
end

for l in io.lines(arg[2]) do
  local w = l:match("^%S+")
  w = w:lower():gsub("^%p+", ""):gsub("%p+$", "")
  if words[w] then
    print(l)
  end
end
