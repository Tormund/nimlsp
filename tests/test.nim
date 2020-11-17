import json, asyncdispatch

proc foo123*()
proc someMegaFunction*()
type MyType = object
  ## This type is for Test purposes
  field: int
  js: JsonNode
var i: MyType
i.field = 10000
echo i.field


#[
  some stuff
]#

proc foo123*() =
  discard

proc someMegaFunction*() =
  echo "mega function ololo"
