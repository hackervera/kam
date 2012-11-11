require 'sinatra'
require 'base64'
class WebServer < Sinatra::Base

  get "/" do
    erb :index
  end

  get "/find" do
    data = Storage::DB.get(params[:key])

    if data.nil? || Kam.sha1(data) != params[:key]
      nodes = Kam.active(Kam.lookup(params[:key]))
      node  = nodes.first
      if node.nil?
        "Couldn't find any peers with the value"
      else
        data = Kam.transfer(node, params[:key])
        Storage::DB.put(params[:key], data)
      end
    end
    data
  end

  get "/find_value" do
    key   = params[:key]
    value = Storage.find_value(key)
    if value
      node_info           = Kam::NODEINFO
      node_info["value"]  = "have"
      node_info["nodeid"] = key
      node_info.to_json
    else
      Storage.bucket_members(Kam.bucket(Kam.distance(key))).to_json
    end
  end

  get "/transfer" do
    Storage::DB.get(params[:key])
  end

  get "/ping" do
    Storage.update_bucket(nodeid: params[:nodeid], ip: params[:ip], port: params[:port]).to_json
    Kam::NODEINFO.to_json
  end

  get "/find_peers" do
    Storage.peers
  end


  def self.run
    run!({ port: Kam::PORT })
  end

end