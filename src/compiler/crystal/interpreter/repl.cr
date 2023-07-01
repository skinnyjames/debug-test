
require "./debug_adapter_protocol/*"

class DebugEmitter
  property active : Bool = false

  @block : Proc(Array(Tuple(String, String, String)),Crystal::Repl::Interpreter, Pointer(UInt8), Crystal::Repl::CompiledInstructions, Pointer(UInt8), Pointer(UInt8), Nil)?
 # node, self, ip, instructions, stack_bottom, stack
  def on_emit(&block : Proc(Array(Tuple(String, String, String)), Crystal::Repl::Interpreter, Pointer(UInt8), Crystal::Repl::CompiledInstructions, Pointer(UInt8), Pointer(UInt8),  Nil))
    @block = block
  end

  def emit(callstack : Array(Tuple(String, String, String)), inter, ip, instructions, stack_bottom, stack)
    if node = callstack
     @block.try(&.call(node, inter, ip, instructions, stack_bottom, stack))
    end
  end
end

class Crystal::Repl
  property prelude : String = "prelude"
  property debug_port : Int32? = nil
  getter program : Program
  getter context : Context
  getter server : DebugAdapterProtocol::Server


  def initialize
    @program = Program.new
    @context = Context.new(@program)
    @main_visitor = MainVisitor.new(@program)
    @emitter = DebugEmitter.new
    @debug_channel = Channel(Symbol).new
    @server = DebugAdapterProtocol::Server.new
    @interpreter = Interpreter.new(@context, emitter: @emitter)

    @emitter.on_emit do |backtrace, inter, ip, instructions, stack_bottom, stack|
      begin

        # filename = nil
        # lineno = nil

        # if location = node.location
        #   location = location.expanded_location || location
        #   filename = location.filename.as(String)
        #   lineno = location.line_number.to_s
        #   column_number = location.column_number
        # end


        # puts match

        backtrace.each do |filename, lineno, column|
          puts "#{filename}:#{lineno}"

          if DebugAdapterProtocol::Data.has_breakpoint?(filename, lineno)
            match = "#{filename}:#{lineno}"
            STDOUT.puts "Breaking on #{match}\n"
            DebugAdapterProtocol::Data.stop!(filename.not_nil!, lineno.not_nil!)
          end
        end

        loop do
          break unless DebugAdapterProtocol::Data.stopped?
          break if DebugAdapterProtocol::Data.disconnected?

          if req = DebugAdapterProtocol::Data.expressions.shift?
            if code = req.arguments.try(&.expression)
              puts "before debug"
              str = inter.interpret_from_debug(code, ip, instructions, stack_bottom, stack) || "<nil>"
              puts "after debug"
              DebugAdapterProtocol::Data.expression_value_block.try(&.call(str, req))
            end
          else
            # dunno
          end

          sleep 0.000001

        end
      rescue ex : Exception
        puts "Exception: #{ex}"
      end
    end
  end

  def run
    load_prelude

    reader = ReplReader.new(repl: self)
    reader.color = @context.program.color?

    reader.read_loop do |expression|
      case expression
      when "exit"
        break
      when .presence
        parser = new_parser(expression)
        parser.warnings.report(STDOUT)

        node = parser.parse
        next unless node

        value = interpret(node)
        print " => "
        puts SyntaxHighlighter::Colorize.highlight!(value.to_s)
      end
    rescue ex : EscapingException
      print "Unhandled exception: "
      print ex
    rescue ex : Crystal::CodeError
      ex.color = @context.program.color?
      ex.error_trace = true
      puts ex
    rescue ex : Exception
      ex.inspect_with_backtrace(STDOUT)
    end
  end

  def run_file(filename, argv)
    @interpreter.argv = argv

    prelude_node = parse_prelude

    if debug_port
      server.start(debug_port.not_nil!)
      loop do
        break if DebugAdapterProtocol::Data.ready?

        sleep 0.000000001
      end
    end

    other_node = parse_file(filename)
    file_node = FileNode.new(other_node, filename)
    exps = Expressions.new([prelude_node, file_node] of ASTNode)
    
    if debug_port
      @emitter.active = true
      interpret_and_exit_on_error(exps, emit: true)
    else
      interpret_and_exit_on_error(exps)
    end

    server.quit(debug_port.not_nil!) if debug_port

    # Explicitly call exit at the end so at_exit handlers run
    interpret_exit
  end

  def run_code(code, argv = [] of String, *, emit : Bool = false) : Value
    @interpreter.argv = argv

    prelude_node = parse_prelude
    other_node = parse_code(code)
    exps = Expressions.new([prelude_node, other_node] of ASTNode)

    interpret(exps, emit: emit)
  end

  private def load_prelude
    node = parse_prelude

    interpret_and_exit_on_error(node)
  end

  private def interpret(node : ASTNode, *, emit : Bool = false)
    @main_visitor = MainVisitor.new(from_main_visitor: @main_visitor)

    node = @program.normalize(node)
    node = @program.semantic(node, main_visitor: @main_visitor)

    @interpreter.interpret(node, @main_visitor.meta_vars, emit: emit)
  end

  private def interpret_and_exit_on_error(node : ASTNode, emit : Bool = false)
    interpret(node, emit: emit)
  rescue ex : EscapingException
    # First run at_exit handlers by calling Crystal.exit
    interpret_crystal_exit(ex)
    exit 1
  rescue ex : Crystal::CodeError
    ex.color = true
    ex.error_trace = true
    puts ex
    exit 1
  rescue ex : Exception
    ex.inspect_with_backtrace(STDOUT)
    exit 1
  end

  private def parse_prelude
    filenames = @program.find_in_path(prelude)
    parsed_nodes = filenames.map { |filename| parse_file(filename) }
    Expressions.new(parsed_nodes)
  end

  private def parse_file(filename)
    parse_code File.read(filename), filename
  end

  private def parse_code(code, filename = "")
    warnings = @program.warnings.dup
    warnings.infos = [] of String
    parser = Parser.new code, @program.string_pool, warnings: warnings
    parser.filename = filename
    parsed_nodes = parser.parse
    warnings.report(STDOUT)
    @program.normalize(parsed_nodes, inside_exp: false)
  end

  private def interpret_exit
    interpret(Call.new(nil, "exit", global: true))
  end

  private def interpret_crystal_exit(exception : EscapingException)
    decl = UninitializedVar.new(Var.new("ex"), TypeNode.new(@context.program.exception.virtual_type))
    call = Call.new(Path.global("Crystal"), "exit", NumberLiteral.new(1), Var.new("ex"))
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      Interpreter.interpret(@context, exps) do |stack|
        stack.as(UInt8**).value = exception.exception_pointer
      end
    rescue ex
      puts "Error while calling Crystal.exit: #{ex.message}"
    end
  end

  protected def new_parser(source)
    Parser.new(
      source,
      string_pool: @context.program.string_pool,
      var_scopes: [@interpreter.local_vars.names_at_block_level_zero.to_set]
    )
  end
end
