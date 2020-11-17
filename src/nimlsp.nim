import nimlsppkg / [ baseprotocol, utfmapping, suggestlib, utils, protocol, messages2, messageenums, lsp ]
import streams, tables, strutils, os, hashes, json, options, times, strformat, sets

const
  version = block:
    var version = "0.0.0"
    let nimbleFile = staticRead(currentSourcePath().parentDir().parentDir() / "nimlsp.nimble")
    for line in nimbleFile.splitLines:
      let keyval = line.split("=")
      if keyval.len == 2:
        if keyval[0].strip == "version":
          version = keyval[1].strip(chars = Whitespace + {'"'})
          break
    version
  # This is used to explicitly set the default source path
  explicitSourcePath {.strdefine.} = getCurrentCompilerExe().parentDir.parentDir

var nimpath = explicitSourcePath

var
  ins = newFileStream(stdin)
  outs = newFileStream(stdout)
  gotShutdown = false
  initialized = false
  projectFiles = initTable[string, tuple[nimsuggest: NimSuggest, openFiles: int]]()
  openFiles = initTable[string, tuple[projectFile: string, fingerTable: seq[seq[tuple[u16pos, offset: int]]]]]()
  messageHandlers = initTable[string, proc(message: JsonNode): JsonNode]()

template respond(req, resp: JsonNode) =
  var r = newJObject()
  r["id"] = req{"id"}
  r["result"] = resp
  # resp["id"] = req{"id"}
  writeLog("<< ", r)
  outs.sendJson(r)

proc none[T](field: var Option[T]) =
  field = none(T)

template makeSuggest(r: Lsp, cmd: untyped, msg: typed): seq[Suggest] =
  let fileUri = msg.params.textDocument.uri
  let position = msg.params.position
  debugLog("sug ", astToStr(cmd), " from ", fileUri, " pos ", position)
  let suggest = r.getSuggest(fileUri)
  if suggest.isNil:
    debugLog("suggest isnil ")
    return
  let res = r.getSuggest(fileUri).`cmd`(
    msg.params.textDocument.uri.toPath(),
    dirtyfile = msg.params.textDocument.uri.stashFile,
    msg.params.position.line + 1,
    msg.params.position.character
  )
  debugLog "Found ", astToStr(cmd), " suggestions: ",
    res[0..(if res.len > 10: 10 else: res.high)],
    (if res.len > 10: " and " & $(res.len-10) & " more" else: "")
  res

template makeSuggestForFile(r: Lsp, cmd: untyped, fileUri: string): seq[Suggest] =
  debugLog("sug ", astToStr(cmd), " from ", fileUri)
  let suggest = r.getSuggest(fileUri)
  if suggest.isNil:
    debugLog("suggest isnil ")
    return
  let res = r.getSuggest(fileUri).`cmd`(
    fileUri.toPath(),
    dirtyfile = fileUri.stashFile
  )
  debugLog "Found ", astToStr(cmd), " suggestions: ", res
  res

template location(sug: Suggest): Location =
  Location(
    uri: sug.filepath.pathToUri(),
    `range`: Range(
      start: Position(line: sug.line - 1, character: sug.column),
      `end`: Position(line: sug.line - 1, character: sug.column + sug.qualifiedPath[^1].len)
    )
  )

registerMessageHandler("initialize") do(r: Lsp, msg: JsonNode) -> JsonNode:
  debugLog "got initialize request ", msg
  var request = msg.to(InitializeRequest)
  var resp: InitializeResult

  resp.serverInfo.name = "nimlsp"
  resp.serverInfo.version = version & "beta"

  resp.capabilities.textDocumentSync.openClose = true
  resp.capabilities.textDocumentSync.change = TextDocumentSyncKind.Full.int
  resp.capabilities.completionProvider.resolveProvider = false
  resp.capabilities.completionProvider.triggerCharacters = @[".", " "]
  resp.capabilities.hoverProvider = true
  resp.capabilities.declarationProvider = false
  resp.capabilities.definitionProvider = true
  # resp.capabilities.typeDefinitionProvider = true
  resp.capabilities.implementationProvider = true
  resp.capabilities.referencesProvider = true
  resp.capabilities.documentSymbolProvider = true
  # resp.capabilities.completionProvider.allCommitCharacters.none()
  # resp.capabilities.signatureHelpProvider.none()
  # resp.capabilities.codeLensProvider = some(CodeLensOptions(resolveProvider: true))
  # resp.capabilities.documentLinkProvider.none()
  # resp.capabilities.documentOnTypeFormattingProvider.none()
  # resp.capabilities.executeCommandProvider.none()
  # resp.capabilities.workspace.none()
  # resp.capabilities.experimental.none()
  # documentHighlightProvider
  # resp.capabilities.renameProvider = true
  result = toMessage(resp)

registerMessageHandler("textDocument/completion") do(r: Lsp, msg: JsonNode) -> JsonNode:
  var request = msg.to(TextDocumentCompletionRequest)
  let suggestions = r.makeSuggest(sug, request)
  var list: seq[CompletionItem]
  var sugLimit = 20
  for i, sug in suggestions:
    if not sug.isValid: continue

    var item: CompletionItem
    item.label = sug.qualifiedPath[^1]
    item.kind = some(nimSymToLSPKind(sug).int)
    item.detail = some(nimSymDetails(sug))
    item.documentation = some(MarkupContent(kind:MarkupKind.plaintext, value:sug.nimDocstring))
    if sug.useSnippet:
      item.insertTextFormat = some(InsertTextFormat.Snippet.int)
    else:
      item.insertTextFormat = some(InsertTextFormat.PlainText.int)

    list.add(item)
    if i >= sugLimit: break
  result = toMessage(CompletionList(isIncomplete: suggestions.len > sugLimit, `items`: list))

registerMessageHandler("textDocument/documentSymbol") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let request = msg.to(TextDocumentSymbolRequest)
  let filePath = request.params.textDocument.uri
  let suggestions = r.makeSuggestForFile(highlight, filePath)

  var relations = initTable[string, DocumentSymbol]()

  var systemSymbol = new(DocumentSymbol)
  systemSymbol.name = "system"
  systemSymbol.kind = CompletionItemKind.Module.int
  systemSymbol.`range` = Range(
    start: Position(line:0, character:0),
    `end`: Position(line:0, character:1)
  )
  systemSymbol.selectionRange = systemSymbol.`range`
  relations["system"] = systemSymbol

  # var symbolsAUX: seq[DocumentSymbolAUX]
  # symbolsAUX.add(DocumentSymbolAUX(symb: systemSymbol, qp: @["system"], id: @["system"].join(".").hash))
  var symbols: seq[DocumentSymbol]
  symbols.add(systemSymbol)

  for sug in suggestions:
    if not sug.isValid or sug.qualifiedPath.len == 0 or not sug.isFrom(filePath): continue
    let id = sug.qualifiedPath.join(".")
    if id in relations: continue

    var si = new(DocumentSymbol)
    si.name = sug.qualifiedPath[^1]
    si.kind = sug.nimSymToLSPSym().int
    si.`range` = Range(
      start: Position(line: sug.line - 1, character: sug.column),
      `end`: Position(line: sug.line - 1, character: sug.column + sug.qualifiedPath[^1].len)
    )
    si.selectionRange = si.`range`
    symbols.add(si)
    relations[id] = si
    if sug.qualifiedPath.len == 1: continue
    let parent = relations.getOrDefault(sug.qualifiedPath[0..^2].join("."))
    if not parent.isNil:
      parent.children.add(si)

  if symbols.len == 0:
    return newJNull()
  result = toMessage(symbols)

# registerMessageHandler("textDocument/codeLens") do(r: Lsp, msg: JsonNode) -> JsonNode:


# go to definition does the same
# registerMessageHandler("textDocument/implementation") do(r: Lsp, msg: JsonNode) -> JsonNode:
#   var request = msg.to(TextDocumentImplementationRequest)
#   debugLog("textDocument/implementation ", msg)
#   let suggestions = r.makeSuggest(sug, request)
#   var resp: seq[Location]
#   for sug in suggestions:
#     if sug.qualifiedPath.len == 0: continue
#     resp.add(Location(
#         uri: sug.filepath.pathToUri(),
#         `range`: Range(
#           start: Position(line: sug.line, character: sug.column),
#           `end`: Position(line: sug.line, character: sug.column + sug.qualifiedPath[^1].len)
#         )
#       )
#     )
#   if resp.len == 0:
#     return newJNull()
#   result = toMessage(resp)

#todo: think how to support it without nimsuggest ...
# registerMessageHandler("completionItem/resolve") do(r: Lsp, msg: JsonNode) -> JsonNode:
#   let request = msg.to(CompletionItemResolveRequest)
#   let suggestions = r.makeSuggest(def, request)
#   if suggestions.len == 0:
#     result = newJNull()

#   var list: seq[CompletionItem]
#   var sugLimit = 20
#   for i, sug in suggestions:
#     if not sug.isValid: continue

#     var item: CompletionItem
#     item.label = sug.qualifiedPath[^1]
#     item.kind = some(nimSymToLSPKind(sug).int)
#     item.detail = some(nimSymDetails(sug))
#     item.documentation = some(MarkupContent(kind:MarkupKind.markdown, value:sug.nimDocstring))
#     item.insertTextFormat = some(InsertTextFormat.PlainText.int)
#     list.add(item)
#     if i >= sugLimit: break
#   result = toMessage(CompletionList(isIncomplete: suggestions.len > sugLimit, `items`: list))

registerMessageHandler("textDocument/hover") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let request = msg.to(TextDocumentHoverRequest)
  let position = request.params.position
  let suggestions = r.makeSuggest(def, request)

  # discard r.makeSuggestForFile(highlight, request.params.textDocument.uri)
  # discard r.makeSuggestForFile(outline, request.params.textDocument.uri)
  # discard r.makeSuggestForFile(known, request.params.textDocument.uri)

  if suggestions.len == 0:
    return newJNull()

  var r: Hover
  let doc = if suggestions[0].doc.len > 0: suggestions[0].doc & "\n" else: ""
  let path = suggestions[0].qualifiedPath.join(".")
  let defin = if suggestions[0].forth.len > 0: suggestions[0].forth else: ""

  var hoverVal = fmt"""
{doc}
`from {path}`
```nim
{defin}
```
"""
    # suggestions[0].qualifiedPath.join(".")
  #   (if suggestions[0].doc.len > 0: suggestions[0].doc & "\n" else: "") & suggestions[0].qualifiedPath.join(".")
  # if suggestions[0].forth.len > 0:
  #   hoverVal &= ": " & suggestions[0].forth

  # r.contents = MarkedStringOption(language: "nim", value: hoverVal)
  r.contents = MarkupContent(kind:MarkupKind.markdown, value: hoverVal)
  if r.contents.value.len == 0:
    return newJNull()

  let wordLen = (if suggestions[0].qualifiedPath.len > 0: suggestions[0].qualifiedPath[^1].len else: 0)
  r.`range` = Range(start: position, `end`: Position(line: position.line, character: position.character + wordLen))
  result = toMessage(r)

registerMessageHandler("textDocument/references") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let request = msg.to(TextDocumentReferencesRequest)

  let suggestions = r.makeSuggest(use, request)
  if suggestions.len == 0:
    return newJNull()

  var resp: seq[Location]
  for sug in suggestions:
    if sug.qualifiedPath.len == 0: continue
    if sug.section == ideUse or request.params.context.includeDeclaration:
      resp.add(sug.location)
  result = toMessage(resp)

registerMessageHandler("textDocument/rename") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let request = msg.to(TextDocumentRenameRequest)
  let suggestions = r.makeSuggest(use, request)
  var changes = initTable[DocumentUri, seq[TextEdit]]()
  for sug in suggestions:
    let k = sug.filepath.pathToUri()
    var list = changes.getOrDefault(DocumentUri(k))
    if sug.qualifiedPath.len == 0: continue
    list.add(
      TextEdit(
        `range`: Range(
          start: Position(line: sug.line, character: sug.column),
          `end`: Position(line: sug.line, character: sug.column + sug.qualifiedPath[^1].len)
          ),
        newText: request.params.newName
      )
    )
    changes[k] = list

  if changes.len == 0:
    return newJNull()
  else:
    var resp:WorkspaceEdit
    resp.changes = some(changes)
    result = toMessage(resp)

registerMessageHandler("textDocument/definition") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let request = msg.to(TextDocumentDefinitionRequest)
  let suggestions = r.makeSuggest(def, request)
  var resp: seq[Location]
  for sug in suggestions:
    if sug.qualifiedPath.len == 0: continue
    resp.add(sug.location)
  if resp.len == 0:
    return newJNull()
  result = toMessage(resp)

registerNotificationHandler("textDocument/didOpen") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let notif = msg.to(DidOpenTextDocumentNotification)
  let fileUri = notif.params.textDocument.uri
  r.onFileOpened(fileUri, notif.params.textDocument.text)

registerNotificationHandler("textDocument/didChange") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let notif = msg.to(DidChangedTextDocumentNotification)
  let fileUri = notif.params.textDocument.uri
  if notif.params.contentChanges.len > 0:
    r.onFileChanged(fileUri, notif.params.contentChanges[0].text)

registerNotificationHandler("textDocument/didClose") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let notif = msg.to(DidCloseTextDocumentNotification)
  let fileUri = notif.params.textDocument.uri
  r.onFileClosed(fileUri)

registerNotificationHandler("textDocument/didSave") do(r: Lsp, msg: JsonNode) -> JsonNode:
  let notif = msg.to(DidSaveTextDocumentNotification)
  let fileUri = notif.params.textDocument.uri
  if notif.params.text.isSome:
    r.onFileChanged(fileUri, notif.params.text.get())

let start = epochTime()
registerMessageHandler("initialized") do(r: Lsp, msg: JsonNode) -> JsonNode:
  debugLog "nimlsp connected! in ", epochTime() - start

debugLog("nimlsp starting...")
proc serve() =
  debugLog("Version: " & version & "gg")
  debugLog("explicitSourcePath: " & explicitSourcePath)
  for i in 1..paramCount():
    debugLog("Argument " & $i & ": " & paramStr(i))

  if paramCount() == 1:
    case paramStr(1):
      of "--help":
        echo "Usage: nimlsp [OPTION | PATH]\n"
        echo "--help, shows this message"
        echo "--version, shows only the version"
        echo "PATH, path to the Nim source directory, defaults to \"", nimpath, "\""
        quit 0
      of "--version":
        echo "nimlsp v", version, "wtf"
        quit 0
      else: nimpath = expandFilename(paramStr(1))
  if not existsFile(nimpath / "config/nim.cfg"):
    stderr.write "Unable to find \"config/nim.cfg\" in \"" & nimpath & "\". " &
      "Supply the Nim project folder by adding it as an argument.\n"
    quit 1

  debugLog "*** NIMLSP STARTED! ***"

  var gLsp = new(Lsp)
  gLsp.init(nimpath)

  while true:
    try:
      debugLog "Trying to read frame"
      let frame = ins.readFrame
      let st = epochTime()
      let message = frame.parseJson
      let meth = message{"method"}.getStr()
      writeLog ">> ", meth, " ", message
      let handler = getHandler(meth)
      # debugLog meth, " handler ", handler.isNil
      if not handler.isNil:
        var resp = gLsp.handler(message)
        if not resp.isNil:
          message.respond(resp)
          debugLog("Respond in ", epochTime() - st)
      else:
        debugLog "Unknown message ", meth, " see log file for details"
        writeLog "Unknown message ", meth, " > ", message
      continue

    except Exception as e:
      debugLog "Got exception: ", e.msg, "\n", getStackTrace(e)
      continue

serve()
debugLog("Exit nimlsp")
