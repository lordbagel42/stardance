module Onboarding
  module FeaturedProjects
    Project = Data.define(:title, :first_name, :age, :location, :url, :thumbnail_url, :interest)

    ALL = [
      # web_dev
      Project.new(title: "MosaicSlicer", first_name: "Rohan", age: 15, location: "US", url: "https://app.mosaicslicer.com", thumbnail_url: "onboarding/featured/mosaicslicer.png", interest: "web_dev"),
      Project.new(title: "Student", first_name: "Aram", age: 15, location: "US", url: "https://student.aram.sh", thumbnail_url: "onboarding/featured/student.png", interest: "web_dev"),
      Project.new(title: "hackatime-heatmap", first_name: "Miguel", age: 18, location: "Portugal", url: "https://hackatime-heatmap.shymike.dev", thumbnail_url: "onboarding/featured/hackatime-heatmap.png", interest: "web_dev"),
      Project.new(title: "networkify", first_name: "Ingo", age: 16, location: "Australia", url: "https://networkify.ingo.au/", thumbnail_url: "onboarding/featured/networkify.png", interest: "web_dev"),
      Project.new(title: "Hack Club Wrapped", first_name: "Daniel", age: 16, location: "Spain", url: "https://wrapped.isitzoe.dev/", thumbnail_url: "onboarding/featured/hackclub-wrapped.png", interest: "web_dev"),

      # hardware
      Project.new(title: "Biblically Accurate Angel Keyboard", first_name: "Alex", age: 16, location: "US", url: "https://www.youtube.com/watch?v=EbvpPsTKe3c", thumbnail_url: "onboarding/featured/angel-keyboard.jpg", interest: "hardware"),
      Project.new(title: "Ender-X4", first_name: "Allen", age: 18, location: "US", url: "https://github.com/ading2210/ender-x4", thumbnail_url: "onboarding/featured/ender-x4.jpg", interest: "hardware"),
      Project.new(title: "StratoSoar MK3", first_name: "Charles", age: 15, location: "US", url: "https://www.youtube.com/watch?v=TiqkcGWG4g8", thumbnail_url: "onboarding/featured/stratosoar.jpg", interest: "hardware"),
      Project.new(title: "Tacocopter", first_name: "Nicholas", age: 17, location: "US", url: "https://www.youtube.com/watch?v=A8tR219AC94", thumbnail_url: "onboarding/featured/tacocopter.jpg", interest: "hardware"),
      Project.new(title: "Tiny4FSK", first_name: "Maxwell", age: 15, location: "US", url: "https://github.com/New-England-Weather-Balloon-Society/Tiny4FSK", thumbnail_url: "onboarding/featured/tiny4fsk.png", interest: "hardware"),

      # app_dev
      Project.new(title: "Liveboard", first_name: "David", age: 15, location: "Australia", url: "https://github.com/MadAvidCoder/Liveboard", thumbnail_url: "onboarding/featured/liveboard.png", interest: "app_dev"),
      Project.new(title: "toad", first_name: "Ingemar", age: 17, location: "Sweden", url: "https://github.com/ingobeans/toad", thumbnail_url: "onboarding/featured/toad.png", interest: "app_dev"),
      Project.new(title: "peek", first_name: "Kareem", age: 16, location: "Egypt", url: "https://github.com/hs7t/peek", thumbnail_url: "onboarding/featured/peek.png", interest: "app_dev"),
      Project.new(title: "ntwatch", first_name: "Lola", age: 17, location: "US", url: "https://github.com/lolasanchezz/ntwatch", thumbnail_url: "onboarding/featured/ntwatch.png", interest: "app_dev"),
      Project.new(title: "timecheck22", first_name: "Lakshya", age: 17, location: "US", url: "https://timecheck22.lraj22.xyz/", thumbnail_url: "onboarding/featured/timecheck22.png", interest: "app_dev"),

      # game_dev
      Project.new(title: "York", first_name: "Krishna", age: 19, location: "India", url: "https://kuratus.itch.io/york", thumbnail_url: "onboarding/featured/york.png", interest: "game_dev"),
      Project.new(title: "Lepidoptera", first_name: "Lev", age: 14, location: "Czech Republic", url: "https://onlyth3best.itch.io/lepidoptera", thumbnail_url: "onboarding/featured/lepidoptera.png", interest: "game_dev"),
      Project.new(title: "OKRIM", first_name: "Ernests", age: 18, location: "Latvia", url: "https://n0o0b090lv.itch.io/okrim-updated", thumbnail_url: "onboarding/featured/okrim.png", interest: "game_dev"),
      Project.new(title: "prode dies", first_name: "Herby", age: 16, location: "Canada", url: "https://herbeon.itch.io/prode-dies", thumbnail_url: "onboarding/featured/prode-dies.png", interest: "game_dev"),
      Project.new(title: "wayward", first_name: "Julia", age: 18, location: "US", url: "https://solacite.itch.io/wayward", thumbnail_url: "onboarding/featured/wayward.png", interest: "game_dev"),

      # ai_ml
      Project.new(title: "iris-classification", first_name: "Shreya", age: 17, location: "US", url: "https://github.com/shreya-0718/iris-classification", thumbnail_url: "onboarding/featured/iris-classification.png", interest: "ai_ml"),
      Project.new(title: "STACKED!", first_name: "Julia", age: 18, location: "US", url: "https://github.com/noahwalshsd/Proto", thumbnail_url: "onboarding/featured/stacked.png", interest: "ai_ml"),
      Project.new(title: "cuber", first_name: "Vuk", age: 17, location: "Canada", url: "https://youtube.com/shorts/K8QNXNZYxWQ", thumbnail_url: "onboarding/featured/cuber.jpg", interest: "ai_ml"),
      Project.new(title: "dragon", first_name: "Shreya", age: 17, location: "US", url: "https://github.com/shreya-0718/dragon", thumbnail_url: "onboarding/featured/dragon.png", interest: "ai_ml"),
      Project.new(title: "Regreso", first_name: "Matidza", age: 18, location: "US", url: "https://regreso.netlify.app", thumbnail_url: "onboarding/featured/regreso.png", interest: "ai_ml"),

      # art_design
      Project.new(title: "out-perform", first_name: "Julia", age: 18, location: "US", url: "https://solacite.itch.io/out-perform", thumbnail_url: "onboarding/featured/out-perform.png", interest: "art_design"),
      Project.new(title: "21st Century Love Story", first_name: "Kaylee", age: 17, location: "US", url: "https://docachon.itch.io/21st-century-love-story", thumbnail_url: "onboarding/featured/21st-century-love-story.png", interest: "art_design"),
      Project.new(title: "pingxel / lumis", first_name: "Marcell", age: 18, location: "Romania", url: "https://youtube.com/shorts/mK0VWQWo5x8", thumbnail_url: "onboarding/featured/lumis.png", interest: "art_design"),
      Project.new(title: "TV-head", first_name: "Tuyet", age: 18, location: "US", url: "https://youtu.be/najtegiIQSQ", thumbnail_url: "onboarding/featured/tv-head.jpg", interest: "art_design"),
      Project.new(title: "axtro", first_name: "Shaaarkai", age: 18, location: "Philippines", url: "https://shaaarkai.itch.io/axtro", thumbnail_url: "onboarding/featured/axtro.png", interest: "art_design")
    ].freeze

    PROJECTS_BY_INTEREST = ALL.group_by(&:interest).freeze

    def self.for_interests(interests, limit: 5)
      interests = Array(interests) & User::ALLOWED_INTERESTS
      return [] if interests.empty?

      if interests.size == 1
        (PROJECTS_BY_INTEREST[interests.first] || []).first(limit)
      else
        selected = []
        pools = interests.map { |i| (PROJECTS_BY_INTEREST[i] || []).dup }
        pools.reject!(&:empty?)

        while selected.size < limit && pools.any?
          pools.each do |pool|
            break if selected.size >= limit
            project = pool.shift
            selected << project if project
          end
          pools.reject!(&:empty?)
        end

        selected
      end
    end
  end
end
