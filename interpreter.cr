require "colorize"

struct Bool
  def to_u16
    self ? 1_u16 : 0_u16
  end
end

class ProgramState(T)
  @@max_stack_size = 65535
  @bool : Bool
  property stack : Deque(T)
  property output : IO
  property a : T
  property b : T
  property r : T
  property c : T

  def initialize
    @bool = true
    @stack = Deque(T).new(@@max_stack_size)
    @input = STDIN
    @output = STDOUT
    @a = T.new(0)
    @b = T.new(1)
    @r = T.new(0)
    @c = T.new(0)
  end

  def push(v : T)
    @stack.push(v)
  end

  def pop
    @stack.pop { T.new(0) }
  end

  def topmost
    @stack.last? || T.new(0)
  end

  def stack_str(io : IO)
    @stack.each do |v|
      io << v.chr
    end
  end

  def open_file
    fname = IO::Memory.new
    stack_str(fname)
    @input = File.open(fname.rewind.gets_to_end)
  end

  def close_file
    @input.close unless @input.tty?
    @input = STDIN
  end

  def read_byte
    byte = @input.read_byte
    @stack.push(T.new(byte)) unless byte.nil?
  end

  def step_right
    @c += 1
  end

  def step_down
    @r += 1
  end

  def step_up
    @r -= 1
  end

  def clear_stack
    @stack.clear
  end

  def truthy=(val)
    @bool = val
  end

  def true?
    @bool
  end

  def debug(io : IO)
    io << "R=#{@r},C=#{@c}  A=#{@a},B=#{@b}  #{true?}\nstack=[#{@stack.join(',')}]\n"
  end
end

alias State = ProgramState(UInt16)
alias StateChange = Proc(State, Nil)

enum InterpreterMode
  Normal
  Literal
  Number
end

class Interpreter
  @@cmds = Hash(UInt8, StateChange).new
  @@nostep_cmds : Set(UInt8) = "RCUuDdSs".bytes.map(&.to_u8).to_set
  @code : Array(String)
  @bytes : Array(Bytes)
  @state : State
  @mode : InterpreterMode

  def initialize(code : String)
    # TODO: handle !#
    @code = code.lines
    @bytes = @code.map(&.to_slice)
    @state = State.new
    @mode = InterpreterMode::Normal
  end

  def step
    instruction = @bytes.dig?(@state.r, @state.c)
    abort if instruction.nil?
    if instruction == '"'.ord.to_u8
      toggle_mode(InterpreterMode::Literal)
    elsif @mode == InterpreterMode::Literal
      @state.push(instruction)
    elsif instruction == '\''.ord.to_u8
      @state.push(parse_num)
    elsif instruction == ' '.ord.to_u8 # spaces are ignored
      nil
    else
      begin
        @@cmds[instruction].call(@state)
      rescue KeyError
        error "Invalid instruction '#{instruction.chr}'"
      end
    end
    @state.step_right unless @mode == InterpreterMode::Normal && instruction.in?(@@nostep_cmds)
  end

  def debug
    output = IO::Memory.new
    @state.output = output
    loop do
      print "\033c" # clear terminal
      @state.debug(STDOUT)
      puts "code:".colorize(:dark_gray)
      @code.each_with_index do |line, idx|
        if idx == @state.r
          print line[0, @state.c], line[@state.c].colorize.back(:magenta), line[@state.c + 1..]
        else
          print line
        end
        puts
      end
      puts "\noutput=\"#{output}\""
      gets
      step
    end
  end

  def run
    loop { step }
  rescue
    abort
  end

  def error(reason : String)
    abort "ERROR: #{reason} at #{@state.r + 1}:#{@state.c}"
  end

  def parse_num
    @state.step_right
    closing_idx = @bytes[@state.r].index('\''.ord.to_u8, @state.c)
    error "Unclosed number literal" if closing_idx.nil?
    closing_idx = closing_idx.to_u16
    literal_str = String.new(@bytes[@state.r][@state.c...closing_idx], "ASCII")
    begin
      num = literal_str.to_u16(whitespace: false, underscore: true, prefix: true, strict: true)
    rescue ArgumentError
      error "Invalid number literal"
    end
    @state.c = closing_idx
    num
  end

  def toggle_mode(toggled : InterpreterMode)
    @mode = @mode == toggled ? InterpreterMode::Normal : toggled
  end

  def self.cmd(v : Char, &block : StateChange)
    @@cmds[v.ord.to_u8] = block
  end

  cmd('A') { |state| state.a = state.pop }                                 # set A
  cmd('a') { |state| state.push(state.a) }                                 # push A
  cmd('B') { |state| state.b = state.pop }                                 # set B
  cmd('b') { |state| state.push(state.b) }                                 # push B
  cmd('R') { |state| state.r = state.pop }                                 # set ROW
  cmd('r') { |state| state.push(state.r) }                                 # push ROW
  cmd('C') { |state| state.c = state.pop }                                 # set COL
  cmd('c') { |state| state.push(state.c) }                                 # push COL
  cmd('?') { |state| state.truthy = (state.pop != 0) }                     # set TRUTHY
  cmd('z') { |state| state.clear_stack }                                   # clear stack
  cmd('U') { |state| state.step_up }                                       # UP
  cmd('D') { |state| state.step_down }                                     # DOWN
  cmd('u') { |state| state.true? ? state.step_up : state.step_right }      # UP (conditional)
  cmd('d') { |state| state.true? ? state.step_down : state.step_right }    # DOWN (conditional)
  cmd('x') { |state| abort if state.true? }                                # exit
  cmd('p') { |state| state.stack_str(state.output) }                       # print entire stack as string
  cmd('P') { |state| state.output << '[' << state.stack.join(' ') << ']' } # print entire stack as numbers
  cmd('#') { |state| state.output << state.topmost }                       # print last as number
  cmd('.') { |state| state.output << state.topmost.chr }                   # print last as char
  cmd(',') { |state| state.output << ' ' }                                 # print a space
  cmd(';') { |state| state.output << '\n' }                                # print a newline
  cmd('+') { |state| state.push(state.pop &+ state.pop) }                  # ADD (wrapping)
  cmd('-') { |state| state.push(state.pop &- state.pop) }                  # SUB (wrapping)
  cmd('*') { |state| state.push(state.pop &* state.pop) }                  # MUL (wrapping)
  cmd('/') { |state| state.push(state.pop // state.pop) }                  # DIV
  cmd('%') { |state| state.push(state.pop % state.pop) }                   # MOD
  cmd('=') { |state| state.push((state.pop == state.pop).to_u16) }         # EQUALS
  cmd('<') { |state| state.push((state.pop < state.pop).to_u16) }          # LESS THAN
  cmd('>') { |state| state.push((state.pop > state.pop).to_u16) }          # GREATER THAN
  cmd('F') { |state| state.open_file }                                     # OPEN FILE
  cmd('f') { |state| state.close_file }                                    # CLOSE FILE
  cmd('g') { |state| state.read_byte }                                     # GETCHAR
  (0_u16..9_u16).each do |num|
    cmd(num.to_s[0]) { |state| state.push(num) }
  end
end
