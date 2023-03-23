require "./interpreter.cr"
require "option_parser"

debugger = false
show_error_location = false

OptionParser.parse do |parser|
  parser.banner = "Usage: horlang [OPTIONS] FILE"

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end

  parser.on("-d", "--debugger", "Enable debugger") do
    debugger = true
  end

  parser.on("-e", "--error-highlight",
    "Show where error occurred if execution stops unexpectedly") do
    show_error_location = true
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

if ARGV.size != 1
  abort "ERROR: Expected one filename as argument (received #{ARGV.size} arguments)"
end

fname = ARGV[0]

if fname == "-"
  code = STDIN.gets_to_end
else
  code = File.read(fname)
end

ip = Interpreter.new(code, show_error_location: show_error_location)

if debugger
  ip.debug
else
  ip.run
end
