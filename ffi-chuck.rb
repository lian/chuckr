require 'ffi'

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

    init_EM_log 0 #8 # debug-level
  end
end



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
