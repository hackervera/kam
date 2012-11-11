require 'json'
require 'gserver'
module RpcServer

  class Proto < GServer
    def initialize
      super(Kam::PORT, Kam::IP, 100)
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
