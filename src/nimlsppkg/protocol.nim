import messages2
import json, options

type
  InitializeRequest* = object
    params*: Option[InitializeParams]

  InitializeResult* = object
    capabilities*: ServerCapabilities
    serverInfo*: ServerInfo
