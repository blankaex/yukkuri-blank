#!/usr/bin/env ruby

require "optparse"
require "fileutils"
require "net/http"
require "uri"
require "json"

def main
  # initialize
  api = ENV["VOICEVOX_URI"]
  options = parseOpts()
  script = loadScript()

  # parse video script
  lines = parseScript(script, options[:all])
  abort("Nothing to do.") if lines.empty?

  # generate tts
  print "Initializing speaker..."
  initSpeaker(api)
  print "\r\e[KSpeaker initialized.\n"

  lines.each do |index, line|
    curr = "\r\e[K[#{format("%04d.wav", index)}]"

    print "#{curr} Generating query..."
    query = generateAudioQuery(api, line)

    print "#{curr} Synthesizing audio..."
    audio = synthesizeAudio(api, query)

    print "#{curr} Writing audio..."
    writeAudio(index, audio, options[:output])

    print "#{curr} Done.\n"
  end
end

def parseOpts()
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] FILE"

    opts.on("-a", "--all", "Generate TTS for every line in file") do
      options[:all] = true
    end

    opts.on("-o DIR", "--output DIR", "Specify output directory for synthesized audio") do |dir|
      options[:output] = dir
    end
  end.parse!
  return options
end

def loadScript()
  script = ARGV[0]
  abort "No script file provided" unless script
  return script
end

def parseScript(script, all)
  lines = File.readlines(script, chomp: true)
  lines = lines.each_with_index.map { |text, i| [i + 1, text] }

  unless all
    input = lines.map { |line, text| "#{line}: #{text}" }.join("\n")

    selected = IO.popen(["sk", "--multi", "--reverse"], "r+") do |io|
      io.write(input)
      io.close_write
      io.read
    end

    lines = selected.lines.map do |line|
      line_number, text = line.chomp.split(": ", 2)
      [line_number.to_i, text]
    end
  end

  return lines
end

def initSpeaker(api)
  uri = URI(api + "/initialize_speaker")
  uri.query = URI.encode_www_form(speaker: 122, skip_reinit: true)

  request = Net::HTTP::Post.new(uri)

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  if !response.is_a?(Net::HTTPSuccess)
    puts("HTTP error: #{response.code} #{response.message}")
    abort(response.body)
  end
end

def generateAudioQuery(api, line)
  uri = URI(api + "/audio_query_from_preset")
  uri.query = URI.encode_www_form(
    text: line,
    preset_id: 0,
    enable_katakana_english: true
  )

  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "application/json"

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  if !response.is_a?(Net::HTTPSuccess)
    puts("HTTP error: #{response.code} #{response.message}")
    abort(response.body)
  else
    return JSON.parse(response.body)
  end
end

def synthesizeAudio(api, query)
  uri = URI(api + "/synthesis")
  uri.query = URI.encode_www_form(
    speaker: 122,
    enable_interrogative_upspeak: true
  )

  request = Net::HTTP::Post.new(uri)
  request["Accept"] = "audio/wav"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(query)

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  if !response.is_a?(Net::HTTPSuccess)
    puts("HTTP error: #{response.code} #{response.message}")
    abort(response.body)
  else
    return response.body
  end
end

def writeAudio(index, audio, output)
  # outputs to `$PWD/output/` if not specified
  output ||= "output"
  FileUtils.mkdir_p(output)

  filename = format("%04d.wav", index)
  File.binwrite(File.join(output, filename), audio)
end

main
