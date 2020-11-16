import messages2
import json, options

type
  InitializeRequest* = object
    params*: Option[InitializeParams]

  InitializeResult* = object
    capabilities*: ServerCapabilities
    serverInfo*: ServerInfo

  TextDocumentCompletionRequest* = object
    params*: CompletionParams

  TextDocumentHoverRequest* = object
    params*: HoverParams



  DidOpenTextDocumentNotification* = object
    params*: DidOpenTextDocumentParams

  DidChangedTextDocumentNotification* = object
    params*: DidChangeTextDocumentParams

  DidCloseTextDocumentNotification* = object
    params*: DidCloseTextDocumentParams

  DidSaveTextDocumentNotification* = object
    params*: DidSaveTextDocumentParams
