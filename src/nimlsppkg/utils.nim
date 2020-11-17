import messageenums
import strutils, uri, os, options, hashes, times

const storage = getTempDir() / "nimlsp"
const auxProjFile = storage / "auxproject.nim.cfg"

discard existsOrCreateDir(storage)

if not fileExists(auxProjFile):
  writeFile(auxProjFile, "")

proc pathToUri*(path: string): string

proc getStorage*(): string = storage

when defined(debugLogging):
  var logPath = when defined(localLogFile): getAppDir() else: storage
  var logFile = open(logPath / "nimlsp_" & $int(epochTime()) & ".log", fmWrite)

template debugLog*(args: varargs[string, `$`]) =
  when defined(debugLogging):
    stderr.write(join args)
    stderr.write("\n")
    logFile.write(join args)
    logFile.write("\n\n")
    logFile.flushFile()

template writeLog*(args: varargs[string, `$`]) =
  when defined(debugLogging):
    logFile.write(join args)
    logFile.write("\n\n")
    logFile.flushFile()

proc toPath*(s: string): string =
  when defined(windows):
    result = s[8..^1]
  else:
    result = s[7..^1]

proc stashFile*(path: string): string =
  storage / (hash(path.toPath).toHex & ".nim" )

proc pathToUri*(path: string): string =
  when defined(windows):
    var path = path.replace("\\", "/")
  result = path
  if result[0] == '/':
    result = "file://" & result
  else:
    result = "file:///" & result

proc isProjectFile(p: string): bool =
  let sp = p.splitFile()
  result = sp.ext in [".nims", ".nim.cfg"]

proc isBuildFile(p: string): bool =
  let sp = p.splitFile()
  result = sp.ext in [".nimble", ".nakefile"]

proc getProjectFile*(path: string): string =
  if path.len == 0: return auxProjFile
  var file = path.decodeUrl

  while result.len == 0 and file.len > 0:
    var (dir, fname, ext) = file.splitFile()
    for f in walkDir(dir):
      if f.path.isProjectFile:
        result = f.path
        break
      elif f.path.isBuildFile:
        debugLog("found proj file ", f.path)
        break
      if result.len != 0:
        break
      file = dir

  if result.len == 0:
    result = auxProjFile

  debugLog("getProjectFile ", path, " r ", result, " isProjectFile ", result.isProjectFile, " isBuildFile ", result.isBuildFile)
