#!/usr/bin/env ruby

require "optparse"
require "fileutils"
require "net/http"
require "uri"
require "json"
require "tmpdir"

def main
  options = parseOpts()
  lines = loadFiles(options[:source], options[:all])
  abort("Nothing to do.") if lines.empty?

  print "Files loaded.\n"

  lines.each do |file, line|
    curr = File.join(options[:output], "#{File.basename(file, File.extname(file))}.webm")
    print "[#{curr}] Generating webm...\n"
    generateWebm(file, line, curr)
    print "[#{curr}] Done.\n"
  end
end

def parseOpts()
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} -i DIR [options] FILE"

    opts.on("-i DIR", "--input DIR", "Specify output directory for synthesized audio") do |dir|
      options[:source] = dir
    end

    opts.on("-o DIR", "--output DIR", "Specify output directory for synthesized audio") do |dir|
      options[:output] = dir
    end

    opts.on("-a", "--all", "Generate TTS for every line in file") do
      options[:all] = true
    end
  end.parse!

  abort("Input directory not provided") unless options[:source]
  options[:output] = options[:source] unless options[:output]
  return options
end

def loadFiles(source, all)
  script = ARGV[0] || abort("No script file provided")
  lines = File.readlines(script, chomp: true)
  lines = lines.each_with_index.map { |text, i| [File.join(source, format("%04d.wav", i + 1)), text] }

  unless all
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

def generateWebm(
  file,
  line,
  output,
  width: 1920,
  height: 1080,
  fps: 30,
  font: "07AkazukinPop Heavy",
  font_size: 100,
  font_color: "&H00FDFDFD",
  outline_color: "&H2D7C4262",
  outline: 4,
  shadow: 2,
  alignment: 2,
  margin_v: 100
)
  duration = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{file}"`.strip.to_f()

  abort("[#{file}] Could not determine audio duration.") if duration <= 0

  timestamp = format(
    "%d:%02d:%05.2f",
    duration / 3600,
    (duration % 3600) / 60,
    duration % 60
  )

  ass_file = File.join(
    Dir.tmpdir,
    "subtitle_#{Process.pid}_#{Thread.current.object_id}.ass"
  )

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
      "-i", file,
      "-vf", "ass=#{ass_file}:alpha=1,format=rgba",
      "-c:v", "libvpx-vp9",
      "-pix_fmt", "yuva420p",
      "-crf", "32",
      "-auto-alt-ref", "0",
      "-c:a", "libopus",
      "-b:a", "128k",
      "-shortest",
      output
    )

    abort "ffmpeg failed for #{file}" unless success
  ensure
    File.delete(ass_file) if File.exist?(ass_file)
  end
end

main
