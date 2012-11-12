require 'leveldb'
require 'json'
module Storage
  DB = LevelDB::DB.new(Kam::CONFIG["storage"])
  class << self
    # structure should be hash with nodeid, ip, and port
    def update_bucket(structure)
      # generate timestamp
      time   = Time.now.to_i
      # determine bucket for nodeid
      bucket = Kam.bucket(Kam.distance(structure["nodeid"] || structure[:nodeid]))
      # grab current bucket members
      current_members = JSON.parse(DB.get(bucket.to_s)) rescue []
      while current_members.length >= 20
        #remove member with oldest timestamp to make room
        marked = current_members.sort_by { |m| m["timestamp"] }.first
        current_members.delete(marked)
      end
      DB.put(bucket.to_s, current_members.to_json)
      node_ids               = Kam.peers.map { |c| c["nodeid"] }
      structure["timestamp"] = time
      if   node_ids.include?(structure[:nodeid] || structure["nodeid"])
        #p "#{structure} already in bucket"
      else
        current_members << structure
        DB.put(bucket.to_s, current_members.to_json)
        p "Adding #{structure} to bucket #{bucket}"  if Kam.active(structure)
      end
    end

    def bucket_members(bucket)
      members = JSON.parse(DB.get(bucket.to_s)) rescue [].map { |m| JSON.parse m }
      if Kam.active(members.uniq_by{|n| n["nodeid"]}).length < 20
        Kam.active(Kam.peers)
      else
        members
      end
    end

    def find_value(key)
      DB.get(key)
    end

    def peers
      DB.each(from: "0", to: "160").map { |_, v| JSON.parse(v) rescue next }.compact.flatten
    end
  end
end