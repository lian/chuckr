require File.dirname(__FILE__) + "/../vendor/ruby-session/lib/session.rb"

module Chuckr
  CHUCK_BIN = File.dirname(__FILE__) + "/../bin/chuckr_bin"
  class VM
    attr_accessor :status
    def initialize(args)
      @config, @shell = args, Session::Shell.new 
      @status = { :running => false, :now => 0, :samps => 0 }
    end

    def start
      # chuck_configure
      chuck_start
    end
    
    def status
      chuck_run '--status'
      @status
    end
    
    def chuck_stdout_callback(stdout)
      matched = false
      
      # match status line - uptime..
      if stdout.match /status \(now == (.+), (.+) samps/
        @status[:now], @status[:samps], @status[:running], matched = $1, $2, true, true
        puts "Stdout_STATUS: #{stdout}"
        tick_callback :status
      end
      
      # match if chunkr_bin vm is killed
      if stdout.match /[0-9] Terminated/
        @status[:now], @status[:samps], @status[:running], matched = 0, 0, false, true
        tick_callback :vm_killed
      end
      
      # print & log unmatched stdout
      puts "Stdout: #{stdout}" unless matched

      return true # allways true
    end
    
    def tick_callback(type)
      puts "tick_callback: #{type.to_s}";true
    end

    def chuck_start
      VM.chuck_check_binary
      pipe_callback = lambda{ |stdout| chuck_stdout_callback(stdout) } 
      @shell.outproc, @shell.errproc = pipe_callback, pipe_callback
      @shell_thread = Thread.new do
        @shell.execute( chuck_command('--loop') ) #  :stdout => @out, :stderr => @err
      end;true
    end

    def chuck_command(cmd);"#{CHUCK_BIN} -p#{@config[:port] || 4031} #{cmd}";end
    def chuck_run(cmd_args);system(chuck_command(cmd_args));end
  end # VM
  
  class VM
    def self.chuck_check_binary
      raise "CHUCK_BIN is missing!" unless File.exists?(CHUCK_BIN) && File.executable?(CHUCK_BIN)
    end
  end # VM
end

# $vm = Chuckr::VM.new( {:port => 4031} )