#!/usr/bin/env ruby

require "fileutils"
require "json"
require "net/http"
require "optparse"
require "pathname"
require "tmpdir"
require "uri"
require "yaml"

def main
  options = parseOpts()
  config = loadConfig()

  lines = loadFiles(config[:dirs][:wavs], options)
  abort("Nothing to do.") if lines.empty?

  print "Files loaded.\n"

  FileUtils.mkdir_p(config[:dirs][:webms])
  lines.each do |audio, line|
    filename = File.join(config[:dirs][:webms], "#{File.basename(audio, File.extname(audio))}.webm")
    print "[#{filename}] Generating webm...\n"
    generateWebm(audio, line, filename, config[:webm])
    print "[#{filename}] Done.\n"
  end
end

def parseOpts()
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] FILE"
    opts.on("-a", "--all", "Generate WebM for every line in file") do
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
  config[:dirs][:wavs] = Pathname(config[:dirs][:wavs]).cleanpath.to_s
  config[:dirs][:webms] = Pathname(config[:dirs][:webms]).cleanpath.to_s
  return config
end

def loadFiles(source, options)
  begin
    lines = File.readlines(options[:input], chomp: true)
                     .each_with_index
                     .filter_map do |text, i|
                       file = File.join(source, format("%04d.wav", i + 1))
                       [file, text] if File.file?(file)
                     end
  rescue SystemCallError => e
    abort "Failed to read #{options[:input]}: #{e.message}"
  end

  unless options[:all]
    input = lines.map { |file, text| "#{file}: #{text}" }.join("\n")

    selected = IO.popen(["sk", "--multi", "--reverse"], "r+") do |io|
      io.write(input)
      io.close_write
      io.read
    end

    lines = selected.lines.map do |line|
      file, text = line.chomp.split(": ", 2)
      abort("[\"#{file}\"] Not found.") unless File.file?(file)
      [file, text]
    end
  end
  
  return lines
end

def generateWebm(audio, line, filename, config)
  width = config[:width]
  height = config[:height]
  fps = config[:fps]
  font = config[:font]
  font_size = config[:font_size]
  font_color = config[:font_color]
  outline = config[:outline]
  outline_color = config[:outline_color]
  shadow = config[:shadow]
  alignment = config[:alignment]
  margin_v = config[:margin_v]

  duration = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{audio}"`.strip.to_f()
  abort("[#{filename}] Could not determine audio duration.") if duration <= 0

  timestamp = format("%d:%02d:%05.2f", duration / 3600, (duration % 3600) / 60, duration % 60)
  ass_file = File.join(Dir.tmpdir, "subtitle_#{Process.pid}_#{Thread.current.object_id}.ass")

  ass = <<~ASS
    [Script Info]
    ScriptType: v4.00+
    WrapStyle: 0
    PlayResX: #{width}
    PlayResY: #{height}

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default,#{font},#{font_size},#{font_color},&H000000FF,#{outline_color},&H80000000,0,0,0,0,100,100,0,0,1,#{outline},#{shadow},#{alignment},100,100,#{margin_v},1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:00.00,#{timestamp},Default,,0,0,0,,#{line}
  ASS

  begin
    File.write(ass_file, ass)

    success = system(
      "ffmpeg",
      "-y",
      "-loglevel", "warning",
      "-stats",
      "-f", "lavfi",
      "-i", "color=c=black@0.0:s=#{width}x#{height}:r=#{fps}:d=#{duration},format=rgba",
      "-channel_layout", "mono",
      "-i", audio,
      "-vf", "ass=#{ass_file}:alpha=1,format=rgba",
      "-c:v", "libvpx-vp9",
      "-pix_fmt", "yuva420p",
      "-crf", "32",
      "-auto-alt-ref", "0",
      "-c:a", "libopus",
      "-b:a", "128k",
      "-shortest",
      filename
    )

    abort("[#{filename}] WebM generation failed.") unless success
  ensure
    File.delete(ass_file) if File.exist?(ass_file)
  end
end

main
