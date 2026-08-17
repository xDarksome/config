use ../content/content.nu
use ../log_entry.nu

use ../event_store.nu 
use ../content_store.nu
use ../view.nu 

export def main [
  --at: datetime,
  ...tags: string
]: nothing -> record {
  if ($tags | length) < 1 {
    error make 'At least one tag is required'
  }

  let tags = ['meme'] | append $tags

  let mime_list = wl-paste --list-types

  let content_type = $mime_list |
    lines |
    each {|mime| content type try-from-mime $mime} |
    where {|type| $type != null} |
    first

  if $content_type == null {
    error make $'Unable to find a supported MIME type: ($mime_list)'
  }

  let mime = $content_type | content type mime
  let bytes = wl-paste --type $mime

  let content = content new $bytes $content_type
  let content_id = $content | content id

  content_store store $content

  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let event = log_entry new '' [$content_id] $tags $at

  event_store store $event

  view update {} $event

  {} | log_entry apply-event $event
}

