require 'digest/sha1'
require 'yaml'
require 'radix'
require 'set'
require 'open-uri'

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

    def distance(node)
      Kam::NODEID.b(16).to_i ^ node.b(16).to_i
    end

    def sha1(value)
      Digest::SHA1.hexdigest(value).upcase
    end

    def ping(peer)
      url = "http://#{peer["ip"]}:#{peer["port"]}/ping?nodeid=#{NODEID}&port=#{PORT}&ip=#{IP}"
      response = open(url).read
      Storage.update_bucket(JSON.parse response)
    rescue Errno::ECONNREFUSED => e
      puts "connection to #{peer} failed"
    rescue OpenURI::HTTPError
      puts "Internal server error"
    rescue => e
      puts e
      puts e.class
      puts e.backtrace
    end

    def transfer(peer, key)
      url   = "http://#{peer["ip"]}:#{peer["port"]}/transfer?key=#{key}"
      open(url).read
    end

    def find_value(alphas, key)
      url = nil
      bodies = []
      alphas.reject{|a| a["ip"].nil?}.each do |peer|
        url =  "http://#{peer["ip"]}:#{peer["port"]}/find_value?key=#{key}"
        response = open(url).read
        bodies << JSON.parse(response)
      end
      bodies
    rescue URI::InvalidURIError
      puts "Bad URI for #{url}"
    end


    def bootstrap
      CONFIG["bootstrap"].each do |peer|
        ping(peer)
      end
    end

    def lookup(key)
      nodes        = alphas(key)
      found_values = []
      counter      = 0
      while found_values.empty?
        counter      += 1
        nodes        = Kam.find_value(nodes, key).flatten
        found_values = nodes.select { |n| n["nodeid"] == key }
        break if counter > 5
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
  NODEID = Kam.nodeid
  NODEINFO = { nodeid: NODEID, port: PORT, ip: IP }

end
require_relative 'storage'
require_relative 'web_server'
