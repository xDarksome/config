use ../content/content.nu
use ../log_entry.nu

use ../event_store.nu 
use ../content_store.nu
use ../view.nu 

export def main [
  --at: datetime,
  --text-file: path,
  --content-files: list<path>,
  --empty,
  ...tags: string
]: nothing -> nothing {
  if ($tags | length) < 1 {
    error make 'At least one tag is required'
  }

  let file_path = if $text_file == null {
    let path = '/tmp/log-entry.md'

    rm --force $path
    touch $path

    if not $empty {
      hx $path
    }

    $path 
  } else {
    $text_file
  }

  let text = open --raw $file_path

  if ($text | str trim) == '' and ($content_files | is-empty) {
    return
  }

  let content = $content_files
    | each {|path| 
      let ext = ($path | split row '.' | get 1)
      let type = content type from-file-ext $ext
      let bytes = open --raw $path | collect | into binary
      content new $bytes $type
    }

  let content_ids = $content | each {|c| $c | content id } | default []

  $content | each {|c| null | content_store store $c }

  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let event = log_entry new $text $content_ids $tags $at

  event_store store $event

  view update {} $event
}
