require 'rake'

desc 'run specs'
task(:spec) { sh 'ruby spec/*.rb' }
task :default => :spec

namespace :chuck do
  desc 'build & install bin/chuckr_bin'
  task :setup => [ :build, :install, :clean ]
  desc 'build vendor/chuck/chuck'
  task :build do
    sh "cd vendor/chuck; make osx-intel" # osx-ppc
  end
  desc "install bin/chuckr_bin"
  task :install do
    build_path = File.dirname(__FILE__) + '/vendor/chuck/chuck'
    bin_path = File.dirname(__FILE__) + '/bin/chuckr_bin'
    if File.exists?(build_path)
      FileUtils.mv(build_path, bin_path)
      puts 'bin/chuckr_bin is installed now!'
    else
      puts 'vendor/chuck/chuck not found! something went wrong..'
    end
  end
  desc "clean vendor/chuck"
  task :clean do
    sh "cd vendor/chuck; make clean"
    puts 'vendor/chuck cleaned'    
  end
end
