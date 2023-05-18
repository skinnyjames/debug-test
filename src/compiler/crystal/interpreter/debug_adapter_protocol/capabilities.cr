require "./protocol_message"

module DebugAdapterProtocol
  record(CapabilitiesEventBody, body : Capabilities) do
    include JSON::Serializable
  end

  class CapabilitiesEvent < Event(CapabilitiesEventBody)
    def initialize(json : String)
      super("capabilities")
      @body = CapabilitiesEventBody.from_json(json)
    end
  end
end
