#!/usr/bin/env ruby
require 'yaml'

status=0
ARGV.each do |file|
  begin
    r = YAML.load_file(file)
  rescue Errno::ENOENT => ex
    $stderr.print "#{file}:ERROR:0:File does not exist!\n"
    status=2
  rescue Psych::SyntaxError => ex
    $stderr.print "#{file}:ERROR:#{ex.line}:#{ex.problem}\n"
    status=1
  rescue Exception => ex
    $stderr.print "Something else went wrong"
  else
    ## Print OK?
  end
end

exit status
