require 'sinatra'
require 'base64'
require 'filemagic'
class WebServer < Sinatra::Base

  get "/" do
    erb :index
  end

  get "/find_node" do
    Storage.bucket_members(Kam.bucket(Kam.distance(params[:key]))).to_json
  end

  get '/closest_node' do
    Kam.closest_node(params[:key])
  end


  post "/store" do
    data =   open(params[:url]).read
    sha1 =   Kam.sha1(data)
    Storage::DB.put(sha1, data)
    sha1
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
    content_type FileMagic.new(FileMagic::MAGIC_MIME).buffer(data)
    data
  end

  get "/find_value" do
    key   = params[:key]
    value = Storage.find_value(key)
    if value
      node_info           = Kam::NODEINFO
      node_info["value"]  = "have"
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