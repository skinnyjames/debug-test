module DebugAdapterProtocol
  class ProtocolMessage
    include JSON::Serializable

    @@seq : Int32 = 0;

    def self.seq
      @@seq
    end

    def self.seq=(v : Int32)
      @@seq = v
    end

    property type : String
    property seq : Int32? = nil

    def initialize(@type : String)
    end

    def increment
      ProtocolMessage.seq += 1
    end

    def to_message
      increment
      self.seq = ProtocolMessage.seq

      json = self.to_json

      length = json.size

      message = <<-EOF
      Content-Length: #{length}\r\n\r\n#{json}
      EOF

      puts "SENDING: #{message}"

      message
    end
  end

  class Event(T) < ProtocolMessage
    property event : String

    @[JSON::Field(key: "body", emit_null: true)]
    property body : T? = nil

    def initialize(@event : String, @body = nil)
      super("event")
    end
  end
 
  class Request(T) < ProtocolMessage 
    property command : String

    @[JSON::Field(key: "arguments", emit_null: true)]
    property arguments : T?

    def initialize(@command : String, @arguments : T)
      super("request")
    end
  end

  record ErrorResponseBody, error : String do
    include JSON::Serializable
  end

  class Response(T) < ProtocolMessage
    property success : Bool
    property command : String
    property message : String? = nil
    
    @[JSON::Field(key: "body", emit_null: true)]
    property body : T? = nil

    property request_seq : Int32

    def initialize(
      *,
      request_seq : Int32?,
      @command : String, 
      @success : Bool,
      @message : String? = nil,
      @body : T?
    )
      @request_seq = request_seq.not_nil!
      super("response")
    end
  end
end