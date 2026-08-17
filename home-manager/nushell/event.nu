export def aggregate-type []: record -> string {
  $in.type | split row '.' | get 0
}

export def aggregate-id []: record -> string {
  $in.aggregate_id
}

export def number []: record -> int {
  $in.number
}

