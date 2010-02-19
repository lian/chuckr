require 'ffi'
require 'yaml'
require 'eventmachine'

module FFI
  module Chuck
    extend FFI::Library
    ffi_lib 'vendor/chuck/libchuck.so'

    attach_function :all_detach, [], :void
    attach_function :signal_pipe, [:int], :void
    attach_function :init_loop, :main, [:int, :pointer], :void
    attach_function :init_EM_log, :EM_setlog, [:int], :int

    # extern C wrap for cpp #oft_send_cmd
    attach_function :exC_otf_send_cmd, [:int, :pointer, :string, :int], :int


    module_function
    def send_cmd(_host, _port, *_args)
      args = _args.map{|i| FFI::MemoryPointer.from_string(i) } + [nil]
      argv = FFI::MemoryPointer.new(:pointer, args.length)
      args.each_with_index { |p, i| argv[i].put_pointer(0, p) }

      exC_otf_send_cmd(args.size-1, argv, _host, _port) == 1
    end

    def start_loop(*_args)
      args = [nil] + _args.map{|i| FFI::MemoryPointer.from_string(i) } + [nil]
      argv = FFI::MemoryPointer.new(:pointer, args.length)
      args.each_with_index { |p, i| argv[i].put_pointer(0, p) }

        # redirect chuck prints
        old_stdout = $stderr.dup; rd, wr = ::IO.pipe
        $stderr.reopen(wr)

      # call chuck_main.cpp main(argc, argv)
      init_loop(args.size-1,  argv)  # [filename, *args, \0]

        # read and close fds
        $stderr.reopen old_stdout; wr.close
        ckout = rd.read; rd.close

      # return chuck output
      ckout
    end

    def run_loop_process(*_args)
      args = [nil] + _args.map{|i| FFI::MemoryPointer.from_string(i) } + [nil]
      argv = FFI::MemoryPointer.new(:pointer, args.length)
      args.each_with_index { |p, i| argv[i].put_pointer(0, p) }

      # call chuck_main.cpp main(argc, argv)
      init_loop(args.size-1,  argv)  # [filename, *args, \0]
    end

    # shorthand to launch a chuck-vm ruby process
    def create(*args); ChVM.create(*args); end

    module ChVM; Devs = []
      def post_init
        Devs << @state = [ self , EM::Queue.new, 0]
        @queue = @state[1]
        pop_loop
      end

      def pop_loop
        @queue.pop { |v| send_data(v << "\n"); pop_loop }
      end

      def send_cmd(msg)
        @queue.push msg
      end

      def receive_data data
        puts data
        #State[:lock] = false
        #puts "#{loop_name} sent me: #{data}"
      end

      def unbind
        puts "loop died: #{get_status.exitstatus}"
      end

      module_function
      def create(*_args)
        init_line, yml = 'FFI::Chuck.run_loop_process(*args)', _args.to_yaml
        cmd = %|ruby -e "$stdout.sync=true;require '#{__FILE__}';yml=(<<-YAML)\n#{yml}\nYAML\nargs=YAML.load(yml); "|
        cm = EM.popen(cmd + init_line, self)
        (Devs.last << cm)[0]
      end
    end

    init_EM_log 0 #8 # debug-level
  end
end


class NotifyTimer
  attr_accessor :o, :s
  def initialize(options={}, &block)
    @o = { every: 5, priority: 20, msg: 'tick', block: block }.merge(options)
    @s = { count: 0 }
    Schedules << self
  end
  def process_event
    puts '0x%x : %i msg: %s' % [object_id, @s[:count] += 1, @o[:msg]]
    if b = @o[:block]
      b.call(self)
    else
      if h = @o[:handler]
        h.call(self)
      end
    end
  end
  def kill
    @timer.cancel
  end
  def create
    @timer = EM::PeriodicTimer.new(@o[:every], method(:process_event))
  end
  Schedules = []
end


if $0 == __FILE__
  require 'eventmachine'
  EM.run do
    FFI::Chuck.create '-p3484', '--loop'


    NotifyTimer.new(title: 'status', every: 5) do |t|
      FFI::Chuck.send_cmd('localhost', 3484, '--status')
    end

    EM::Timer.new(20) do
      FFI::Chuck.send_cmd('localhost', 3484, '--kill')
      EM::Timer.new(5) { EM.stop }
    end

    NotifyTimer::Schedules.each(&:create)
  end
end



__END__
require 'bacon'; Bacon.summary_on_exit

describe 'FFI::Chuck  libchuck.so #main' do
  Listen = ['localhost', 4022 ]

  it 'initializes' do
    lambda { FFI::Chuck }.should.not.raise NameError
  end

  it 'prints --help' do
    help = FFI::Chuck.start_loop('--help')
    help.should != ''
    help.should.include? "chuck --[options|commands] [+-=^] file1 file2 file3"
  end

  it 'prints --version' do
    help = FFI::Chuck.start_loop('--version')
    help.should.include? "\nchuck version: "
    help.should.include? "\n   exe target: "
    help.should.include? "\n   http://chuck.cs.princeton.edu/\n\n"
  end

  it 'sends command to VM' do
    FFI::Chuck.send_cmd(*Listen, '--status').should == true
  end

  it 'adds shred' do
    # check missing file
    FFI::Chuck.send_cmd(*Listen, '--add', 'test.ck').should == false
  end
end
