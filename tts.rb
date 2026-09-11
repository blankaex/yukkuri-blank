#!/usr/bin/env ruby

require "fileutils"
require "json"
require "net/http"
require "optparse"
require "pathname"
require "uri"
require "yaml"

def main
  options = parseOpts()
  config = loadConfig()

  lines = loadScript(options)
  abort("Nothing to do.") if lines.empty?

  print "Initializing speaker..."
  initSpeaker(config[:tts])
  print "\r\e[KSpeaker initialized.\n"

  FileUtils.mkdir_p(config[:dirs][:wavs])
  lines.each do |index, line|
    filename = File.join(config[:dirs][:wavs], format("%04d.wav", index))

    print "\r\e[K[#{filename}] Generating query..."
    query = generateAudioQuery(config[:tts], line)

    print "\r\e[K[#{filename}] Synthesizing audio..."
    audio = synthesizeAudio(config[:tts], query)

    print "\r\e[K[#{filename}] Writing audio..."
    writeAudio(filename, audio)

    print "\r\e[K[#{filename}] Done.\n"
  end
end

def parseOpts()
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] FILE"
    opts.on("-a", "--all", "Generate TTS for every line in file") do
      options[:all] = true
    end
  end.parse!
  options[:input] = ARGV[0]
  return options
end

def loadConfig()
  begin
    config = YAML.load_file(File.join(__dir__, "config.yml"), symbolize_names: true)
  rescue StandardError => e
    abort("Unable to load config: #{e.message}")
  end
  config[:tts][:voicevox_uri] = ENV["VOICEVOX_URI"] if ENV["VOICEVOX_URI"]
  config[:dirs][:wavs] = Pathname(config[:dirs][:wavs]).cleanpath.to_s
  return config
end

def loadScript(options)
  begin
    lines = File.readlines(options[:input], chomp: true)
                     .each_with_index
                     .map { |text, i| [i + 1, text] }
  rescue SystemCallError => e
    abort("Failed to read #{options[:input]}: #{e.message}")
  end

  unless options[:all]
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

def initSpeaker(config)
  uri = URI(config[:voicevox_uri] + "/initialize_speaker")
  uri.query = URI.encode_www_form(speaker: config[:speaker_id], skip_reinit: true)

  request = Net::HTTP::Post.new(uri)

  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  if !response.is_a?(Net::HTTPSuccess)
    puts("HTTP error: #{response.code} #{response.message}")
    abort(response.body)
  end
end

def generateAudioQuery(config, line)
  uri = URI(config[:voicevox_uri] + "/audio_query_from_preset")
  uri.query = URI.encode_www_form(
    text: line,
    preset_id: config[:preset_id],
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

def synthesizeAudio(config, query)
  uri = URI(config[:voicevox_uri] + "/synthesis")
  uri.query = URI.encode_www_form(
    speaker: config[:speaker_id],
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

def writeAudio(filename, audio)
  begin
    File.binwrite(filename, audio)
  rescue SystemCallError => e
    abort "[#{filename}] Wav generation failed."
  end
end

main
