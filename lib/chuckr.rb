require File.dirname(__FILE__) + "/../vendor/ruby-session/lib/session.rb"

module Chuckr
  CHUCK_BIN = File.dirname(__FILE__) + "/../bin/chuckr_bin"
  class VM
    attr_accessor :status
    def initialize(args)
      @config, @shell = args, Session::Shell.new 
      @config[:port] ||= 4031
      @config[:tmp_path] = "/tmp/chuckr_vm/#{@config[:port]}"
      @status = { :running => false, :now => 0, :samps => 0 }
      @shreds, @shreds_binding, @pid = {}, {}, nil
    end

    def start
      chuck_configure
      chuck_start
    end
    
    def stop
      chuck_run '--kill'; sleep 0.2
      @shell.close; VM.chuck_force_kill(@config[:port])
    end

    def inject_vm_callback(shred);
      shred.vm = self # if shred.respond_to?(:vm=)
    end

    def add_shred(shred)
      if shred.respond_to?(:to_chuck) && shred.respond_to?(:shred_id)
        puts "adding #{shred.shred_id}"
        inject_vm_callback(shred)
        shred_file = "#{@config[:tmp_path]}/#{shred.shred_id}.ck"
        File.open(shred_file,"wb") { |f| f.print shred.to_chuck }
        chuck_run "--add #{shred_file}"
      end
    end
    
    def remove_shred(shred_id)
      if active_shred = shreds[shred_id]
        @shreds.delete(shred_id)
        puts "removing #{shred_id} #{active_shred.inspect}"
        chuck_run "--remove #{active_shred[:vm_id]}"
      end
    end
    
    def replace_shred(shred_id,new_shred)
      if old_shred = @shreds[shred_id]
        if new_shred.respond_to?(:to_chuck) && new_shred.respond_to?(:shred_id)
          puts "replace #{shred_id} with #{new_shred.shred_id}"
          @shreds_binding[new_shred.shred_id] = new_shred
          shred_file = "#{@config[:tmp_path]}/#{new_shred.shred_id}.ck"
          File.open(shred_file,"wb") { |f| f.print new_shred.to_chuck }
          chuck_run "--replace #{old_shred[:vm_id]} #{shred_file}"
        end
      end
    end
    
    def chuck_configure
      setup_tmp_path
    end

    def setup_tmp_path
      tmp_root = "/tmp/chuckr_vm"
      tmp_path = tmp_root+"/#{@config[:port]}"
      Dir.mkdir(tmp_root) unless File.exists?(tmp_root)
      Dir.mkdir(tmp_path) unless File.exists?(tmp_path)
    end
    
    def status
      chuck_run '--status'
      @status
    end
    
    def shreds
      chuck_run '--status'
      @shreds
    end
    
    def chuck_stdout_callback(stdout)
      matched = false
      puts "Stdout_DEBUG: #{stdout.inspect}"

      # [chuck](VM): status (now == 0h0m24s, 1063168.0 samps)
      if stdout.match /status \(now == (.+), (.+) samps/
        @status[:now], @status[:samps], @status[:running], matched = $1, $2, true, true
        tick_callback :status
      end
      
      # [shred id]: 1  [source]: foo.ck  [sporked]: 21.43s ago
      if stdout.match /\[shred id\]\: (.+)  \[source\]: (.+)\.ck  \[spork time\]\: (.+)s ago/
        matched = true
        @shreds[$2] = { :vm_id => $1, :sporked => $3 }
        tick_callback :shreds
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
      end;sleep(0.2);true
    end

    def chuck_command(cmd);"#{CHUCK_BIN} -p#{@config[:port] || 4031} #{cmd}";end
    def chuck_run(cmd_args);system(chuck_command(cmd_args));end
  end # VM
  
  class VM
    def self.chuck_check_binary
      raise "CHUCK_BIN is missing!" unless File.exists?(CHUCK_BIN) && File.executable?(CHUCK_BIN)
    end
    def self.chuck_force_kill(port=nil)
      raise "pass a port to force_kill" unless port
      pids = `ps aux | grep -v "grep" | grep "chuckr_bin -p#{port} --loop"`.split("\n")
      pids.each { |line| pid = line.split(" ")[1];
        system("kill #{pid}")
        puts "chuckr_bin pid:#{pid} force killed!"
      };true
    end
  end # VM
end

class Foo
  attr_accessor :title, :shred_id, :gain, :mix, :vm, :time
  def initialize(title)
    @title, @shred_id = title, title+"-1"
    @gain, @mix = 0.2, 0.1
    @time = 100
    @vm = nil
  end
  def replace!
    return nil unless @vm
    # @vm.replace_shred(@shred_id,self)
    @vm.remove_shred @shred_id
    @vm.add_shred self
  end
  def to_chuck
    %{
      SinOsc s => JCRev r => dac;
      #{@gain} => s.gain;
      #{@mix} => r.mix;
      [ 0, 2, 4, 7, 9, 11 ] @=> int hi[];
      while( true )
      {
          Std.mtof( 45 + Std.rand2(0,3) * 12 +
              hi[Std.rand2(0,hi.cap()-1)] ) => s.freq;
          #{@time}::ms => now;
      }
    }
  end
end