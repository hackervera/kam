require 'sinatra'
class WebServer < Sinatra::Base

  get "/" do
    erb :index
  end

  get "/find" do
    Kam.lookup(params[:key]).to_json
  end

  def self.run
    run!
  end
end