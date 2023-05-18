module DebugAdapterProtocol
  record(
    StoppedEventBody,
    reason : String,
    hitBreakpointIds : Array(Int32),
    text : String? = nil,
    description : String? = nil,
    threadId : String? = nil,
    preserveFocusHint : Bool? = nil,
    allThreadsStopped : Bool? = nil,
  ) do
    include JSON::Serializable
  end
end