module Chuckr
  CHUCK_BIN = File.dirname(__FILE__) + "/../bin/chuckr_bin"
  class VM
    def initialize(args)
      @config = args
    end
    
    def start
      raise "CHUCK_BIN is missing!" unless File.exists?(CHUCK_BIN) && File.executable?(CHUCK_BIN)
      @chuck_io = IO.popen "#{chuck_cmd('--loop')} 2>&1", 'r+'
      @chuck_io_queue = Queue.new
      @chuck_io_thread = Thread.new(self) { |p|  p.read_thread }
      @chuck_io_log = []
    end
    
    def stop
      return if @chuck_io.closed?
      # stop quit! process
      @chuck_io.close
      @chuck_io_thread.join
    end
    
    def status
      system chuck_cmd('--status')
      unless @chuck_io_queue.empty?
        puts str = @chuck_io_queue.pop
      end
    end
    
    def chuck_cmd(cmd)
      "#{CHUCK_BIN} -p#{@config[:port]} #{cmd}"
    end

    def read_thread # only called by @chuck_io_thread
      buff = ''
      begin
        until @chuck_io.eof?
          buff += @chuck_io.read 1
          puts "read_thread: #{buff}"
          next unless (i = buff.index(/[\r\n]/))
          puts "read_thread: LINE FINISHED"
          @chuck_io_queue.push buff.slice!(0, i+1).strip
        end
      rescue
        return
      end
    end
    
  end # VM
end