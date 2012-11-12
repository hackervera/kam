require 'cinch'
bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "irc.freenode.org"
    c.channels = ["#pdxbots"]
  end

  on :message, /http(.+)/ do |m, query|
    query = "http#{query}"
    #m.reply "testing, #{query}"
    command = "curl 'http://localhost:4545/node_store' --data-urlencode 'url=#{query}'"
    #m.reply command
    m.reply `#{command}`
  end
end

bot.start
