import suggestlib, utils
import json, tables, os
export suggestlib

type
  LspMessageHandler* = proc(r: Lsp, msg: JsonNode): JsonNode
  NimProject* = object
    path*: string
    suggest*: NimSuggest
    openFiles*: seq[string]

  Lsp* = ref object
    nimpath*: string
    projects*: Table[string, NimProject]
    openFiles: Table[string, string]
    defaultSuggest: NimSuggest

proc init*(l: Lsp, nimpath: string) =
  l.nimpath = nimpath
  let projAux = getProjectFile("")
  l.defaultSuggest = initNimsuggest(projAux, l.nimpath)

proc getSuggest*(l: Lsp, path: string): NimSuggest =
  if path in l.openFiles:
    let proj = l.openFiles[path]
    if proj in l.projects:
      return l.projects[proj].suggest
  return l.defaultSuggest

proc onFileOpened*(l: Lsp, path: string, text: string) =
  var projFile = path.toPath().getProjectFile()
  if projFile in l.projects:
    l.projects[projFile].openFiles.add(path)
    return

  debugLog("onFileOpened ", path, " ", path.toPath, " ", path.stashFile)
  writeFile(path.stashFile, text)

  var proj: NimProject
  proj.path = projFile
  proj.suggest = initNimsuggest(projFile, l.nimpath)
  proj.openFiles.add(path)
  l.projects[projFile] = proj
  l.openFiles[path] = projFile

  # copyFile(path.toPath, path.toPath.stashFile)

proc onFileChanged*(l: Lsp, path: string, text: string) =
  # discard tryRemoveFile(path.stashFile)
  # copyFile(path.toPath, path.stashFile)
  writeFile(path.stashFile, text)

proc onFileClosed*(l: Lsp, path: string) =
  # discard tryRemoveFile(path.stashFile)
  var projFile = path.toPath().getProjectFile()
  if projFile in l.projects:
    let i = l.projects[projFile].openFiles.find(path)
    if i != -1:
      l.projects[projFile].openFiles.del(i)
    # todo: think about it
    if l.projects[projFile].openFiles.len == 0:
      discard l.projects[projFile].suggest.stopNimSuggest()
  if path in l.openFiles:
    l.openFiles.del(path)

var gMessageHandlers = initTable[string, LspMessageHandler]()

proc registerMessageHandler*(str: string, cb: LspMessageHandler) =
  gMessageHandlers[str] = cb

proc registerNotificationHandler*(str: string, cb: LspMessageHandler) =
  gMessageHandlers[str] = cb

proc getHandler*(str: string): LspMessageHandler =
  gMessageHandlers.getOrDefault(str)
