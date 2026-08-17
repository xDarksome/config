use ../article.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  source: string
  --at: datetime
  --text-file: path
  ...tags: string
]: nothing -> nothing {
  if ($tags | length) < 1 {
    error make 'At least one tag is required'
  }

  let file_path = if $text_file == null {
    let path = '/tmp/article.md'

    rm --force $path
    touch $path
    hx $path

    $path 
  } else {
    $text_file
  }

  let text = open --raw $file_path

  if ($text | str trim) == '' {
    return
  }

  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let created = article new $source $text $tags $at 

  event_store store $created

  view update {} $created
}
