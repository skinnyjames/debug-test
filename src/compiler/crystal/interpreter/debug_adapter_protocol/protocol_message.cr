module DebugAdapterProtocol
  class ProtocolMessage
    include JSON::Serializable

    property seq : Int32
    property type : String

    def initialize(@type : String)
      @seq = 1
    end

    def increment
      @seq += 1
    end

    def to_message
      json = self.to_json

      length = json.size

      message = <<-EOF
      Content-Length: #{length}\r\n\r\n#{json}
      EOF

      message
    end
  end

  class Event(T) < ProtocolMessage
    property event : String
    property body : T?

    def initialize(@event : String, @body = nil)
      super("event")
    end
  end
 
  class Request(T) < ProtocolMessage 
    property command : String
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
    property body : T? = nil

    property request_seq : Int32

    def initialize(
      *,
      @request_seq : Int32,
      @command : String, 
      @success : Bool,
      @message : String? = nil,
      @body : T?
    )
      super("response")
    end
  end
end