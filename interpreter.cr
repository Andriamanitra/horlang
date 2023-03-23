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

  def jump_to(row, col)
    @r = row
    @c = col
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
  @@nostep_cmds : Set(UInt8) = "RCUuDdJj".bytes.map(&.to_u8).to_set
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

  cmd('A') { |st| st.a = st.pop }                                         # set A
  cmd('a') { |st| st.push(st.a) }                                         # push A
  cmd('B') { |st| st.b = st.pop }                                         # set B
  cmd('b') { |st| st.push(st.b) }                                         # push B
  cmd('R') { |st| st.r = st.pop }                                         # set ROW
  cmd('r') { |st| st.push(st.r) }                                         # push ROW
  cmd('C') { |st| st.c = st.pop }                                         # set COL
  cmd('c') { |st| st.push(st.c) }                                         # push COL
  cmd('J') { |st| st.jump_to(st.pop, st.pop) }                            # JUMP
  cmd('j') { |st| st.true? ? st.jump_to(st.pop, st.pop) : st.step_right } # JUMP (conditional)
  cmd('?') { |st| st.truthy = (st.pop != 0) }                             # set TRUTHY
  cmd('z') { |st| st.clear_stack }                                        # clear stack
  cmd('U') { |st| st.step_up }                                            # UP
  cmd('D') { |st| st.step_down }                                          # DOWN
  cmd('u') { |st| st.true? ? st.step_up : st.step_right }                 # UP (conditional)
  cmd('d') { |st| st.true? ? st.step_down : st.step_right }               # DOWN (conditional)
  cmd('x') { |st| abort if st.true? }                                     # exit
  cmd('p') { |st| st.stack_str(st.output) }                               # print entire stack as string
  cmd('P') { |st| st.output << '[' << st.stack.join(' ') << ']' }         # print entire stack as numbers
  cmd('#') { |st| st.output << st.topmost }                               # print last as number
  cmd('.') { |st| st.output << st.topmost.chr }                           # print last as char
  cmd(',') { |st| st.output << ' ' }                                      # print a space
  cmd(';') { |st| st.output << '\n' }                                     # print a newline
  cmd('+') { |st| st.push(st.pop &+ st.pop) }                             # ADD (wrapping)
  cmd('-') { |st| st.push(st.pop &- st.pop) }                             # SUB (wrapping)
  cmd('*') { |st| st.push(st.pop &* st.pop) }                             # MUL (wrapping)
  cmd('/') { |st| st.push(st.pop // st.pop) }                             # DIV
  cmd('%') { |st| st.push(st.pop % st.pop) }                              # MOD
  cmd('=') { |st| st.push((st.pop == st.pop).to_u16) }                    # EQUALS
  cmd('<') { |st| st.push((st.pop < st.pop).to_u16) }                     # LESS THAN
  cmd('>') { |st| st.push((st.pop > st.pop).to_u16) }                     # GREATER THAN
  cmd('F') { |st| st.open_file }                                          # OPEN FILE
  cmd('f') { |st| st.close_file }                                         # CLOSE FILE
  cmd('g') { |st| st.read_byte }                                          # GETCHAR
  ('0'..'9').each do |num|
    val = num.to_u8
    cmd(num) { |state| state.push(val) }
  end
end
