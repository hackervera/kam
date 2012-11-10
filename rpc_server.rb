require 'json'
require 'gserver'
module RpcServer

  class Proto < GServer
    def initialize
      super(Kam::PORT, Kam::IP, 100)
    end

    def serve(io)
      loop do
        input = io.gets
        structure = JSON.parse(input) rescue { }
        case structure["command"]
          when "find_node"
            key = structure["key"]
            io.puts Kam.peers.to_json
          when "find_value"
            key   = structure["key"]
            value = Storage.find_value(key)
            if value
              node_info          = Kam::NODEINFO
              node_info["value"] = value
              node_info["nodeid"] = key
              io.puts(node_info.to_json)
            else
              io.puts Storage.bucket_members(Kam.bucket(Kam.distance(key))).to_json
            end
          when "ping"
            Storage.update_bucket(structure).to_json
            io.puts(Kam::NODEINFO.to_json)
          when "find_peers"
            io.puts Storage.peers
          else
            io.puts "unknown command".to_json
        end
      end
    end
  end
  PROTO       = Proto.new
  PROTO.audit = true
  PROTO.debug = true


  class << self
    def start
      PROTO.start
      sleep 1000000
    end
  end


end
