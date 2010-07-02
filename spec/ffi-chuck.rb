require 'bacon'; Bacon.summary_on_exit

require_relative '../lib/ffi-chuck.rb'

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

