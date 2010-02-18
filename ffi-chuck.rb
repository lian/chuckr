require 'ffi'
require 'socket'


module FFI
  module Chuck
    extend FFI::Library
    ffi_lib 'vendor/chuck/libchuck.so'
    attach_function :all_detach, [], :void
    attach_function :signal_pipe, [:int], :void
    attach_function :init, :main, [:int, :pointer], :void


    module_function
    def start_loop(*_args)
      # prepare *argv[]
      args = [nil] + _args.map{|i| FFI::MemoryPointer.from_string(i) } + [nil]
      argv = FFI::MemoryPointer.new(:pointer, args.length)
      args.each_with_index { |p, i| argv[i].put_pointer(0, p) }

        # redirect chuck prints
        old_stdout = $stderr.dup; rd, wr = ::IO.pipe
        $stderr.reopen(wr)

      # call chuck_main.cpp main(argc, argv)
      init(args.size-1,  argv)  # [filename, *args, \0]

        # read and close fds
        $stderr.reopen old_stdout; wr.close
        ckout = rd.read; rd.close

      # return chuck output
      ckout
    end
  end
end


require 'bacon'; Bacon.summary_on_exit

describe 'FFI::Chuck  libchuck.so #main' do

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
end
