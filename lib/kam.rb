# encoding: utf-8
require 'digest/sha1'
require 'yaml'
require 'radix'
require 'set'
require 'open-uri'
require 'rest_client'

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

    def nodeid
      Kam::sha1("#{IP}:#{PORT}")
    end

    def distance(node, node2=Kam::NODEID)
      node2.b(16).to_i ^ node.b(16).to_i
    end

    def sha1(value)
      Digest::SHA1.hexdigest(value).upcase
    end

    def ping(peer)
      url      = "http://#{peer["ip"]}:#{peer["port"]}/ping?nodeid=#{NODEID}&port=#{PORT}&ip=#{IP}"
      response = open(url).read
      Storage.update_bucket(JSON.parse response)
    rescue Errno::ECONNREFUSED => e
      puts "connection to #{peer} failed"
    rescue OpenURI::HTTPError
      puts "Internal server error"
    rescue URI::InvalidURIError
      puts "invalid url: #{url}"
    rescue SocketError
      puts "bad socket for #{url}"
    rescue => e
      puts e
      puts e.class
      puts e.backtrace
    end


    def transfer(peer, key)
      url = "http://#{peer["ip"]}:#{peer["port"]}/transfer?key=#{key}"
      open(url).read
    end


    def store(peers, data)
      peers.each do |peer|
        next if Kam::NODEID == peer["nodeid"]
        RestClient.post "http://#{peer["ip"]}:#{peer["port"]}/store", data.read, :content_type => 'application/octet-stream'
      end
    end


    def find_value(nodes, key)
      url    = nil
      bodies = []
      nodes.each do |peer|
        url      = "http://#{peer["ip"]}:#{peer["port"]}/find_value?key=#{key}"
        response = open(url).read
        bodies << JSON.parse(response)
      end
      bodies  || []
    rescue URI::InvalidURIError
      puts "Bad URI for #{url}"
    rescue Errno::ECONNREFUSED
      puts "#{url} seems to be down"
    end

    def find_node(nodes, key)
      url    = nil
      bodies = []
      nodes.each do |peer|
        url      = "http://#{peer["ip"]}:#{peer["port"]}/find_node?key=#{key}"
        response = open(url).read
        bodies << JSON.parse(response)
      end
      bodies
    rescue URI::InvalidURIError
      puts "Bad URI for #{url}"
    rescue Errno::ECONNREFUSED
      puts "#{url} seems to be down"
    rescue OpenURI::HTTPError
      puts "#{url} not found"
    end


    def bootstrap
      CONFIG["bootstrap"].each do |peer|
        ping(peer)
      end
    end

    def closest_node(key)
      nodes = alphas(key)
      nodes = (Kam.find_node(nodes, key) || []).flatten.uniq_by { |n| n["nodeid"] }.reject{|n| n["nodeid"] == NODEID}
      nodes = alphas(key) if nodes.empty?
      nodes.each { |n| n["distance"] = Kam.distance(n["nodeid"], key) }.sort_by { |d| d["distance"] }.first(20)
    end

    def lookup(key)
      nodes        = alphas(key)
      found_values = []
      counter      = 0
      while found_values.empty?
        counter += 1
        nodes   = Kam.find_value(nodes, key).flatten
        found_values = nodes.select { |n| n["value"] == "have" }
        break if counter > 5 || nodes.empty?
      end
      found_values.uniq
    end


    def bucket(distance)
      (0..160).to_a.find do |b|
        2**b <= distance && distance < 2**(b+1)
      end
    end

    def active(nodes)
      nodes.reject do |peer|
        ping(peer).nil? ? true : false
      end
    end

    def alphas(key)
      bucket = Kam::bucket(Kam::distance(key))
      nodes  = Storage.bucket_members(bucket).uniq_by { |m| m["nodeid"] }.first(3).to_set
      nodes  = active(nodes).to_set
      if nodes.length < 3
        nodes += active(Kam.peers).uniq_by { |m| m["nodeid"] }.first(3-nodes.length).to_set
      end
      nodes.to_a.reject { |n| n["nodeid"] == NODEID }
    end

    def peers
      Storage.peers.uniq_by { |n| n["nodeid"] }
    end
  end


  CONFIG   = YAML.load_file(ARGV[0] || File.dirname(__FILE__)+"/../config/config.yml")
  PORT     = CONFIG["port"]
  IP       = CONFIG["ip"]
  NODEID   = Kam.nodeid
  NODEINFO = { nodeid: NODEID, port: PORT, ip: IP }

end
require_relative 'storage'
require_relative 'web_server'
