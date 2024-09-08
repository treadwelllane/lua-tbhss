local test = require("santoku.test")
local tbhss = require("tbhss")
local bm = require("santoku.bitmap")
local str = require("santoku.string")

test("encode", function ()

  local triplets = {
    -- Domain: Technology
    {
      anchor = "A computer program can be written in multiple programming languages.",
      positive = "Software can be developed using various coding languages.",
      negative = "Computers are used to solve mathematical problems."
    },
    -- Domain: Health
    {
      anchor = "Regular exercise improves cardiovascular health.",
      positive = "Frequent physical activity benefits heart health.",
      negative = "Eating a balanced diet is essential for overall well-being."
    },
    -- Domain: Travel
    {
      anchor = "Paris is known for its iconic Eiffel Tower and rich history.",
      positive = "The Eiffel Tower is a famous landmark in Paris.",
      negative = "New York is home to Broadway and the Statue of Liberty."
    },
    -- Domain: Finance
    {
      anchor = "Investing in stocks can yield high returns over time.",
      positive = "Stocks have the potential to generate substantial profits.",
      negative = "Saving money in a bank account offers low interest rates."
    },
    -- Domain: Education
    {
      anchor = "Studying hard and attending classes regularly lead to academic success.",
      positive = "Consistent study habits and class attendance are key to good grades.",
      negative = "Extracurricular activities are important for personal development."
    },
    -- Domain: Sports
    {
      anchor = "Playing soccer requires good teamwork and strategy.",
      positive = "Soccer is a team sport that relies heavily on coordination.",
      negative = "Running is a great way to stay fit and healthy."
    },
    -- Domain: Literature
    {
      anchor = "Shakespeare's plays are known for their complex characters and themes.",
      positive = "The works of Shakespeare are rich in intricate characters and motifs.",
      negative = "Modern novels often explore contemporary social issues."
    },
    -- Domain: Food
    {
      anchor = "Italian cuisine is famous for its pasta and pizza dishes.",
      positive = "Pasta and pizza are popular staples in Italian cooking.",
      negative = "Sushi is a traditional Japanese dish made with rice and seafood."
    },
    -- Domain: Environment
    {
      anchor = "Recycling helps reduce waste and conserve natural resources.",
      positive = "Proper recycling practices can minimize environmental impact.",
      negative = "Electric cars are designed to reduce greenhouse gas emissions."
    },
    -- Domain: History
    {
      anchor = "The American Revolution led to the independence of the United States.",
      positive = "The US gained independence following the American Revolution.",
      negative = "The Industrial Revolution brought significant technological advancements."
    },
    -- Domain: Music
    {
      anchor = "Jazz music is characterized by its improvisation and swing feel.",
      positive = "Improvisation is a key feature of jazz music.",
      negative = "Classical music often follows strict compositional rules."
    },
    -- Domain: Art
    {
      anchor = "Impressionist painters focus on light and color rather than detailed realism.",
      positive = "The Impressionist movement emphasizes the effects of light and color.",
      negative = "Realist art aims to depict subjects with precise detail."
    },
    -- Domain: Science
    {
      anchor = "Photosynthesis is the process by which plants convert sunlight into energy.",
      positive = "Plants use sunlight to produce energy through photosynthesis.",
      negative = "Newton's laws describe the relationship between motion and force."
    },
    -- Domain: Technology (Software)
    {
      anchor = "Machine learning algorithms can improve their performance over time.",
      positive = "Over time, machine learning models become more accurate.",
      negative = "Traditional software does not evolve based on data."
    },
    -- Domain: Fashion
    {
      anchor = "Fashion trends often change seasonally.",
      positive = "Seasonal changes influence current fashion trends.",
      negative = "Comfort is a key factor in choosing casual clothing."
    },
    -- Domain: Automobiles
    {
      anchor = "Electric vehicles are powered by batteries rather than gasoline.",
      positive = "Batteries power electric cars instead of gasoline engines.",
      negative = "Gasoline engines are common in traditional cars."
    },
    -- Domain: Social Media
    {
      anchor = "Social media platforms allow users to share updates and connect with others.",
      positive = "Users can share posts and interact through social media.",
      negative = "Email communication is a more formal method of interaction."
    },
    -- Domain: Space Exploration
    {
      anchor = "NASA's missions have significantly advanced our understanding of space.",
      positive = "Space exploration by NASA has expanded our knowledge of the universe.",
      negative = "The study of marine biology focuses on oceanic life forms."
    },
    -- Domain: Literature (Genres)
    {
      anchor = "Science fiction often explores futuristic technology and space travel.",
      positive = "Futuristic themes are central to science fiction literature.",
      negative = "Historical fiction revolves around past events and periods."
    },
    -- Domain: Cooking
    {
      anchor = "Baking requires precise measurements and timing for best results.",
      positive = "Accurate measurements are crucial in baking.",
      negative = "Grilling involves cooking food over an open flame."
    },
    -- Domain: Health (Diet)
    {
      anchor = "A balanced diet includes a variety of nutrients essential for health.",
      positive = "Varied nutrients from different foods contribute to a balanced diet.",
      negative = "Regular exercise is important for maintaining a healthy lifestyle."
    }
  }

  local encoder = tbhss.encoder(
    "test/res/snli5.db", "snli5",
    "test/res/snli5.bin")

  for i = 1, #triplets do
    local t = triplets[i]
    local a, n, p =
      bm.from_raw(encoder.encode(t.anchor)),
      bm.from_raw(encoder.encode(t.negative)),
      bm.from_raw(encoder.encode(t.positive))
    local dan = bm.hamming(a, n)
    local dap = bm.hamming(a, p)
    if dap >= dan then
      print(str.format("Failed. d(n) == %d, d(p) == %d", dan, dap))
      print("  Anchor:", t.anchor)
      print("  Negative:", t.negative)
      print("  Positive:", t.positive)
    else
      print(str.format("Succeeded. d(n) == %d, d(p) == %d", dan, dap))
      print("  Anchor:", t.anchor)
      print("  Negative:", t.negative)
      print("  Positive:", t.positive)
    end
  end

end)
