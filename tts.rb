#!/usr/bin/env ruby

require "optparse"
require "fileutils"
require "net/http"
require "uri"
require "json"

api = "https://voicevox.blankaex.reisen"

def main()
  # initialize
  all = parseOpts()
  script = loadScript()

  # parse video script
  lines = parseScript(script, all)

  # generate tts
  for line in lines
    puts line
  end

  # generate video clips
end

def parseOpts()
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: yukkuri-blank.rb [options] FILE"

    opts.on("-a", "--all", "Operate on every line in sequence") do
      options[:all] = true
    end
  end.parse!
  return options[:all]
end

def loadScript()
  script = ARGV[0]
  abort "No script file provided" unless script
  return script
end

def parseScript(script, all)
  lines = File.readlines(script)
  lines = `printf "#{lines.join()}" | sk --multi --reverse` unless all
  return lines
end

def encodeUri(line)
end

main()
