require 'digest/sha1'
require 'yaml'
require 'radix'
require 'set'

class Array
  def uniq_by(&blk)
    transforms = []
    self.select do |el|
      should_keep = !transforms.include?(t=blk[el])
      transforms << t
      should_keep
    end
  end
end

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
      ready = IO.select([s], nil, nil, 3)
      if ready
        resp = JSON.parse(s.gets)
      else
        return
      end
      Storage.update_bucket(resp)
    end

    def bootstrap
      CONFIG["bootstrap"].each do |peer|
        begin
          TCPSocket.open(peer["ip"], peer["port"]) do |s|
            ping(s)
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
            s.puts({ command: "find_node", key: key }.to_json)
            resp = s.gets
            JSON.parse(resp).each { |node| nodes<< node unless node["nodeid"] == Kam::NODEID }
          end
        rescue Errno::ECONNREFUSED
          next
        end
        nodes.flatten
      end
    end

    def lookup(key)
      nodes = alphas(key)
      found_values = []
      counter = 0
      while found_values.empty?
        counter += 1
        nodes = Kam.find_value(nodes, key)
        found_values = nodes.select { |n| n["nodeid"] == key }
        break if counter > 5
      end
      found_values.uniq
    end

    def find_value(alphas, key)
      nodes = []
      alphas.each do |peer|
        next if peer["nodeid"] == Kam::NODEID
        resp = nil
        begin
          TCPSocket.open(peer["ip"], peer["port"]) do |s|
            s.puts({ command: "find_value", key: key }.to_json)
            ready = IO.select([s], nil, nil, 3)
            if ready
              resp = s.gets
            else
              next
            end
          end
          next if resp.nil?
          if resp["value"]
            nodes << JSON.parse(resp)
          else
            JSON.parse(resp).each { |node| nodes<< node unless node["nodeid"] == Kam::NODEID }
          end
        rescue Errno::ECONNREFUSED
          next
        end
      end
      nodes.flatten
    end


    def bucket(distance)
      (0..160).to_a.find do |b|
        2**b <= distance && distance < 2**(b+1)
      end
    end

    def active(nodes)
      nodes.reject do |peer|
        connected = nil
        TCPSocket.open(peer["ip"], peer["port"]) do |s|
          connected = s
        end rescue nil
        connected.nil?
      end
    end

    def alphas(key)
      bucket = Kam::bucket(Kam::distance(key))
      nodes  = Storage.bucket_members(bucket).first(3).to_set
      nodes  = active(nodes).to_set
      if nodes.length < 3
        nodes += active(Kam.peers).first(3-nodes.length).to_set
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
