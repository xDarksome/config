export use ./type.nu

export def new [bytes: binary, type: record]: nothing -> record {
  if ($bytes | is-empty) {
    error make 'Empty `bytes`'
  }

  $type | type validate

  {
    id: ($bytes | hash sha256)
    bytes: $bytes,
    type: $type
  }  
}

def is-valid []: record -> bool {
  (
    ($in | columns) == ['id', 'bytes', 'type'] and
    ($in.id | describe) == 'string' and
    ($in.bytes | describe) == 'binary' and
    not ($in.bytes | is-empty) and
    ($in.bytes | hash sha256) == $in.id and
    ($in.type | type is-valid)
  )
}

export def validate []: record -> record {
  if not ($in | is-valid) {
    error make $'Invalid Content: ($in)'
  }

  $in
}

export def id []: record -> string {
  ($in | validate).id
}

export def bytes []: record -> binary {
  ($in | validate).bytes
}

export def type []: record -> record {
  ($in | validate).type
}
