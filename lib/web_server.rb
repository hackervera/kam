require 'sinatra'
require 'base64'
require 'filemagic'
class WebServer < Sinatra::Base

  enable :logging
  disable :show_exceptions

  get "/" do
    erb :index
  end

  get "/find_node" do
    Storage.bucket_members(Kam.bucket(Kam.distance(params[:key]))).to_json
  end


  post "/store" do
    data = request.body.read
    sha1 = Kam.sha1(data)
    Storage::DB.put(sha1, data)
  end

  post "/node_store" do
    data  = open(params[:url])
    sha1  = Kam.sha1(open(params[:url]).read)
    nodes = Kam.closest_node(sha1)
    Kam.store(nodes, data)

    "Storing data as #{sha1} visit at http://pdxbrain.com:8585/find?key=#{sha1}"
  end


  get "/find" do
    data = Storage::DB.get(params[:key])

    if data.nil? || Kam.sha1(data) != params[:key]
      nodes = Kam.active(Kam.lookup(params[:key]))
      node = nodes.first
      if node.nil?
        return "Couldn't find any peers with the value"
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
      node_info          = Kam::NODEINFO
      node_info["value"] = "have"
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

  get "/peers" do
    Kam.active(Kam.peers).to_json
  end


  def self.run
    run!({ port: Kam::PORT })
  end

end