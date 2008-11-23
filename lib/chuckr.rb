require 'open3'
module Chuckr
  CHUCK_BIN = File.dirname(__FILE__) + "/../bin/chuckr_bin"
  class VM
    attr_accessor :io
    def initialize(args)
      @config = args
    end
    
    def start
      raise "CHUCK_BIN is missing!" unless File.exists?(CHUCK_BIN) && File.executable?(CHUCK_BIN)
      @io_thread = Thread.new do
        io = Open3.popen3 "#{ chuck_cmd '--loop' }"
        @io = { :in => io[0], :out => io[1], :err => io[2], :thread => io[3] }
      end
      @read_thread = Thread.new do
        @io[:out].sync = true ### you can do this once
        loop do
          puts buf = @io[:out].gets
          # pipe.flush ### or this after each write
        end
      end
    end
    
    def status
      system chuck_cmd('--status')
      # read_out
      # @io[:out].gets
    end
    
    def chuck_cmd(cmd)
      "#{CHUCK_BIN} -p#{@config[:port]} #{cmd}"
    end
        
    def read_out # only called by @chuck_io_thread
      buff = ''
      begin
        until @io[:out].eof?
          buff += @io[:out].read 1
          next unless (i = buff.index(/[\r\n]/))
          # @chuck_io_queue.push buff.slice!(0, i+1).strip
          puts buff.slice!(0, i+1).strip
        end
      rescue
        return
      end
    end
    
  end # VM
end