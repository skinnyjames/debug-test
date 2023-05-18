module DebugAdapterProtocol
  record(
    ValueFormat,
    hex : Bool = false
  ) do
    include JSON::Serializable
  end
  record(
    EvaluateRequestArguments,
    expression : String,
    context : String? = nil,
    frameId : Int32? = nil,
    format : ValueFormat? = nil
  ) do
    include JSON::Serializable
  end

  record(
    EvaluateResponseBody,
    result : String,
    type : String? = nil,
    presentiationHint : Nil = nil, # skipo this
    variablesReference : Int32 = 0,
    namedVariables : Int32? = nil,
    indexedVariables : Int32? = nil,
    memoryReference : String? = nil
  ) do
    include JSON::Serializable
  end

  record(
    ContinueRequestArguments,
    threadId : Int32,
    singleThread : Bool?
  ) do
    include JSON::Serializable
  end

  record(
    ContinueResponseBody,
    allThreadsContinued : Bool? = true
  ) do 
    include JSON::Serializable
  end
end