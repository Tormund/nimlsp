import json

type MyTyp* = object
  field: SomeNumber

echo i
for i in 0 ..< 10:
  var i: MyTyp
  i.field = 100500
  echo i.field
