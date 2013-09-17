#!/usr/bin/env ruby
require 'yaml'

status=0

def check_file(filename)
  status=0
  begin
    r = YAML.load_file(filename)
  rescue Errno::ENOENT => ex
    $stderr.print "#{filename}:ERROR:0:File does not exist!\n"
    status=1
  rescue Psych::SyntaxError => ex
    $stderr.print "#{filename}:ERROR:#{ex.line}:#{ex.problem}\n"
    status=1
  rescue Exception => ex
    $stderr.print "Something else went wrong"
  else
    ## Print OK?
  end
  status
end

ARGV.each do |file|
  if File.directory?(file)
    $stdout.print "#{file}:INFO:Is a directory. Scanning for *.yaml\n"
    Dir.glob("#{file}/**/*.yaml").each do |f|
      s = check_file(f)
      status = s unless s == 0

    end
  else
    s = check_file(file)
    status = s unless s == 0
  end
end

exit status
