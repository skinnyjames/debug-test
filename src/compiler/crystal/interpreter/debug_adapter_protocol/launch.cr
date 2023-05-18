require "./protocol_message"

module DebugAdapterProtocol
  record(
    LaunchRequestArguments,
    noDebug : Bool?,
    __restart : String? = nil
  )

  class LaunchRequest < Request(LaunchRequestArguments)
    command : String = "launch"
    arguments : LaunchRequestArguments
  end
end