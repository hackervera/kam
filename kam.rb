require 'digest/sha1'
require 'yaml'
require 'radix'
require 'set'
module Kam

  class << self
    def distance(node)
      Kam::NODEID.b(16).to_i ^ node.b(16).to_i
    end

    def sha1(value)
      Digest::SHA1.hexdigest(value).upcase
    end

    def ping(s)
      s.puts({ command: "ping", nodeid: NODEID, port: PORT, ip: IP }.to_json)
      resp = JSON.parse(s.gets)
      p "ping response: #{resp}"
      resp.each { |r| Storage.update_bucket(r) }
      #p Storage.update_bucket(JSON.parse resp)
    end

    def bootstrap
      CONFIG["bootstrap"].each do |peer|
        p "wtf"
        begin
          TCPSocket.open(peer["ip"], peer["port"]) do |s|
            s.puts({ command: "ping", nodeid: NODEID, port: PORT, ip: IP }.to_json)
            resp = JSON.parse(s.gets)
            p "ping response: #{resp}"
            resp.each { |r| Storage.update_bucket(r) }
            #p Storage.update_bucket(JSON.parse resp)
          end
        rescue Errno::ECONNREFUSED
          next
        end
      end
    end

    def find_node(alphas, key)
      nodes = []
      alphas.each do |peer|
        next if peer["nodeid"] == Kam::NODEID
        begin
          TCPSocket.new(peer["ip"], peer["port"]) do |s|
            s.puts({ command: "ping", nodeid: NODEID, port: PORT, ip: IP }.to_json)
            resp = s.gets
            p Storage.update_bucket(JSON.parse resp)
            s.puts({ command: "find_node", key: key }.to_json)
            resp = s.gets
            JSON.parse(resp).each { |node| nodes<< node unless node["nodeid"] == Kam::NODEID }
            #nodes.each{|node| p Storage.update_bucket(node)}
          end
        rescue Errno::ECONNREFUSED
          next
        end

        nodes.flatten
      end
    end

    def find_value(alphas, key)
      nodes = []
      alphas.each do |peer|
        next if peer["nodeid"] == Kam::NODEID
        begin
          TCPSocket.open(peer["ip"], peer["port"]) do |s|
            ping(s)
            s.puts({ command: "find_value", key: key }.to_json)
            p "waiting on find_value"
            resp = s.gets

            if resp.nil?
              next
            end

            if resp["value"]
              nodes << JSON.parse(resp)
            else
              JSON.parse(resp).each { |node| nodes<< node unless node["nodeid"] == Kam::NODEID }
            end


          end
        rescue Errno::ECONNREFUSED
          next
        end

        #nodes.each{|node| p Storage.update_bucket(node)}
      end
      nodes.flatten
    end


    def bucket(distance)
      (0..160).to_a.find do |b|
        2**b <= distance && distance < 2**(b+1)
      end
    end

    def alphas(key)
      p bucket = Kam::bucket(Kam::distance(key))
      nodes = Storage.bucket_members(bucket).first(3).to_set
      if nodes.length < 3
        nodes += Kam.peers.first(3-nodes.length).to_set
      end
      nodes.to_a.reject { |n| n["nodeid"] == NODEID }
    end

    def peers
      Storage.peers
    end
  end


  CONFIG = YAML.load_file(ARGV[0] || File.dirname(__FILE__)+"/config.yml")
  PORT   = CONFIG["port"]
  IP     = CONFIG["ip"]

  NODEID   = Kam::sha1("#{IP}:#{PORT}")
  NODEINFO = { nodeid: NODEID, port: PORT, ip: IP }

end
require_relative 'rpc_server'
require_relative 'storage'
