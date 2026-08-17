def supported-types []: nothing -> list<record> {
  [
    (new "image/png" ["png"]), 
    (new "image/jpeg" ["jpg", "jpeg"])
    (new "image/gif"  ["gif"])
    (new "image/webp" ["webp"])
    (new "image/svg+xml" ["svg"])
    (new "application/pdf" ["pdf"])
    (new "video/mp4" ["mp4"])
  ]  
}

def new [mime: string, file_ext: list<string>]: nothing -> record {
  {
    mime: $mime,
    file_ext: $file_ext,
  }
}

export def try-from-mime [mime]: nothing -> record {
  let mime = $mime | str downcase
  (supported-types | where {|type| $type.mime == $mime} | first)
}

export def from-mime [mime]: nothing -> record {
  let type = try-from-mime $mime
  if $type == null {
    error make $'Unsupported MIME: ($mime)'
  }
  $type
}

export def try-from-file-ext [file_ext]: nothing -> record {
  let file_ext = $file_ext | str downcase
  (supported-types | where {|type| $file_ext in $type.file_ext} | first)
}

export def from-file-ext [file_ext]: nothing -> record {
  let type = try-from-file-ext $file_ext
  if $type == null {
    error make $'Unsupported file extension: ($file_ext)'
  }
  $type
}

export def is-valid []: record -> bool {
  (supported-types | any {|type| $type == $in})
}

export def validate []: record -> nothing {
  if not ($in | is-valid) {
    error make $"Invalid Content Type: ($in)"
  }

  $in.mime
}

export def mime []: record -> string {
  $in | validate
  $in.mime
} 

export def file-ext []: record -> string {
  $in | validate
  $in.file_ext | get 0
} 
