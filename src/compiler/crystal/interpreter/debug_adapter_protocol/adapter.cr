module DebugAdapterProtocol
  class Data
    # need to track bp ids
    # the hash key is the file
    # the value is an array of id, bp tuples.
    @@breakpoints = {} of String => Array(Tuple(Int32, SourceBreakpoint))
    @@expressions = [] of Request(EvaluateRequestArguments)
    @@disconnect = false
    @@stopped_breakpoint : Tuple(String, Tuple(Int32, SourceBreakpoint))? = nil
    @@on_expression_value : Proc(String, Request(EvaluateRequestArguments), Nil)? = nil
    @@breakpoint_count = 0

    def self.increment_bp_count
      @@breakpoint_count += 1
      @@breakpoint_count
    end

    def self.ready!
      @@ready = true
    end

    def self.ready?
      @@ready
    end

    def self.on_expression_value(&block : String, Request(EvaluateRequestArguments) -> Nil)
      @@on_expression_value = block
    end

    def self.expression_value_block
      @@on_expression_value
    end

    def self.has_breakpoint?(file : String?, line : String?) : Bool
      return false if file.nil? && line.nil?
      breakpoints.any? do |key, bps|
        file == key && bps.any? { |_, bp| bp.line.to_s == line }
      end
    end

    def self.has_breakpoint?(file : String, breakpoint : SourceBreakpoint) : Bool
      breakpoints[file].incldes?(breakpoint)
    end

    def self.stop!(file : String, line : String)
      @@stopped_breakpoint = find_breakpoint(file, line)
    end

    def self.stopped?
      !stopped_breakpoint.nil?
    end

    def self.stopped_breakpoint
      @@stopped_breakpoint
    end

    def self.resume!
      @@stopped_breakpoint = nil
    end

    def self.remove_breakpoint(file : String, line : String)
      breakpoints.each do |key, bp_arr|
        if key == file
          bp_arr.each_with_index do |(id, bp), idx|
            bp_arr.delete_at(idx) if bp.line.to_s == line
          end
        end
      end
    end

    def self.find_breakpoint(file : String, line : String) : Tuple(String, Tuple(Int32, SourceBreakpoint))?
      bps = breakpoints.reduce([] of Tuple(String, Tuple(Int32, SourceBreakpoint))) do |memo, (key, bp_arr)|
        if key == file
          if rec = bp_arr.find { |id, bp| bp.line.to_s == line }
              id, bp = rec
              memo << { key, { id, bp } }
          end
        end
        memo
      end
      
      bps[0]?
    end

    def self.disconnect
      @@disconnect = true
    end
  
    def self.disconnected?
      @@disconnect
    end

    def self.breakpoints : Hash(String, Array(Tuple(Int32, SourceBreakpoint)))
      @@breakpoints
    end
  
    def self.expressions : Array(Request(EvaluateRequestArguments))
      @@expressions
    end

    def self.to_breakpoints_response(req_seq : Int32)
      bps = breakpoints.reduce([] of Breakpoint) do |memo, (_, bps)|
        bps.each do |bp_tuple|
          
          id, bp = bp_tuple

          memo << Breakpoint.new(
            verified: true, # sure,
            id: id,
            line: bp.line,
          )
        end

        memo
      end

      args = SetBreakpointsResponseArgs.new(breakpoints: bps)
      Response(SetBreakpointsResponseArgs).new(request_seq: req_seq, command: "setBreakpoints", success: true, body: args)
    end
  end

  class Server
    @@debug_server : TCPServer?
  
    def start(port)
      spawn start_server(server(port))
    end
  
    def quit(port)
      server(port).close
    end

    protected def error(request_seq : Int32, command : String, err : String) : String
      res = Response(ErrorResponseBody).new(request_seq: request_seq, command: command, success: false, body: ErrorResponseBody.new(error: err))

      res.to_message
    end

    protected def receive_initialize_request(client)
      seq, type, command, json = parse_dap(client)

      if type != "request" && command != "initialize"
        client << error(seq, command, "Expecting initialize :(")
      end

      # ignore for now...
      _ = Request(InitializeRequestArguments).from_json(json)

      # send our capabilities
      res = Response(Capabilities).new(request_seq: seq, command: command, success: true, body: Capabilities.new)
      client << res.to_message
    end
  
    # sends an initalized event to the IDE.
    protected def send_initialized_event(client)
      client << Event(Nil).new("initialize").to_message
    end

    # only should respond to a setBreakpoints request.
    protected def receive_configuration_request(client)
      loop do
        seq, type, command, json = parse_dap(client)

        # break out of loop here
        if type == "request" && command == "configurationDone"
          client << Response(Nil).new(request_seq: seq, command: command, success: true, body: nil).to_message
          break
        end

        if type != "request" && command != "setBreakpoints"
          client << error(seq, command, "Can only call setBreakpoints :(")
        end

        breakpoints_request = Request(SetBreakpointsArguments).from_json(json)
        breakpoints_request.arguments.try do |args|
          args.breakpoints.try do |breakpoints|
            args.source.path.try do |path|
              Data.breakpoints[path] = breakpoints.map do |bp|
                id = Data.increment_bp_count

                { id, bp }
              end
            end
          end
        end

        res = Data.to_breakpoints_response(seq)
        client << res.to_message

        sleep 0.00000000001
      end
    end

    protected def generate_id_for_bp(path, bp)
      "#{path}::#{bp.line}::#{bp.colum}"
    end

    protected def subscription_loop(client)
      loop do
              
        # puts "client has nothing in it"
        handle_stopped_breakpoint(client)
        # else
        #   puts "client buffer has stufff"
        #   receive_setbreakpoints_request(client)
        # end
        sleep 0.00000000001
      end
    end

    protected def receive_setbreakpoints_request(client)
      seq, type, command, json = parse_dap(client)

      if type == "request" && command == "setBreakpoints"
        breakpoints_request = Request(SetBreakpointsArguments).from_json(json)
        breakpoints_request.arguments.try do |args|
          args.breakpoints.try do |breakpoints|
            args.source.path.try do |path|
              Data.breakpoints[path] = breakpoints.map do |bp|
                id = Data.increment_bp_count

                { id, bp }
              end
            end
          end
        end

        res = Data.to_breakpoints_response(seq)
        client << res.to_message
      else
        client << error(seq, command, "#{command} is not supported")
      end
    end

    protected def receive_launch_or_attach_request(client)
      seq, type, command, json = parse_dap(client)

      if type == "request" && ["launch", "attach"].includes?(command)
        Data.ready!
        client << Response(Nil).new(request_seq: seq, command: command, success: true, body: nil).to_message
      elsif type == "request"
        client << error(seq, command, "#{command} is not supported")
      end
    end

    protected def handle_stopped_breakpoint(client)
      if tuple = Data.stopped_breakpoint
        puts "We have a stop"

        file, bp_tuple = tuple
        id, bp = bp_tuple

        hits = id ? [id] : [] of Int32

        event = Event(StoppedEventBody).new(
          event: "stopped",
          body: StoppedEventBody.new(reason: "breakpoint", description: "stopped on #{file}:#{bp.line}", hitBreakpointIds: hits),
        )

        puts "Sending stopped event to client: #{event.to_message}"

        client << event.to_message

        puts "Entering repl state."
        # enter repl state.
        loop do
          puts "In repl state."

          seq, type, command, json = parse_dap(client)

          if type == "request" && command == "evaluate"
            req = Request(EvaluateRequestArguments).from_json(json)

            got_message = false
            # listen for the expression
            puts "adding expression"
            Data.on_expression_value do |value, req|
              res = Response(EvaluateResponseBody).new(
                request_seq: req.seq,
                command: "evaulate",
                success: true,
                body: EvaluateResponseBody.new(result: value, type: "?")
              )
      
              client << res.to_message
              got_message = true
              sleep 0.00000000001
            end
      
            Data.expressions << req

            while !got_message
              sleep 1
            end

          elsif type == "request" && command == "continue"
            # don't really care about the details
            req = Request(ContinueRequestArguments).from_json(json)
            res = Response(ContinueResponseBody).new(request_seq: seq, command: command, success: true, body: ContinueResponseBody.new)
            client << res.to_message
            Data.resume!
            break          
          else
            puts "invalid repl state"
            sleep 1
          end
        end
      end
    end

    # Bool | Char | Crystal::Type | Float32 | Float64 | Int128 | Int16 | Int32 | Int64 | Int8 | Pointer(UInt8) | String | UInt128 | UInt16 | UInt32 | UInt64 | UInt8 | Nil
    def jsonable_value(value) : Bool | Nil | String | Int64 | Float64
      case value
      when Bool, Nil, String
        value
      when Pointer(UInt8)
        String.new(value)
      when Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8
        value.to_i64
      when Float32 | Float64 
        value
      when Crystal::Type
        value.to_json
      when Char
        "#{value}"
      end
    end
  
    def handle_client(client)
      receive_initialize_request(client)
      send_initialized_event(client)
      receive_configuration_request(client)
      receive_launch_or_attach_request(client)
      puts "Starting subscription loop"
      subscription_loop(client)
    end

    private def parse_dap(client)
      content_length_message = client.gets("\r\n\r\n", chomp: true).not_nil!

      _, length = content_length_message.split(":").map(&.strip)

      puts "Content-Length: #{length}"

      json = client.gets(length.to_i32).not_nil!

      puts "Json Message: #{json}"

      hash = JSON.parse(json)

      type = hash["type"].as_s
      seq = hash["seq"].as_i
      command = hash["command"].as_s

      {seq, type, command, json}
    end
  
    private def start_server(server)
      while client = server.accept?
        spawn handle_client(client)
      end
    end
  
    private def server(port : Int32) : TCPServer
      @@debug_server ||= TCPServer.new("127.0.0.1", port)
    end
  end
end