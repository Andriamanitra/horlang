require "./interpreter.cr"
require "option_parser"

OptionParser.parse do |parser|
  debugger = false
  show_error_location = false
  parser.banner = "Horlang vALPHA"
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
  parser.unknown_args do |args|
    abort "ERROR: Expected one filename as argument (received #{args.size} arguments)" if args.size != 1
    fname = args[0]

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
  end
end
