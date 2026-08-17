use ../content/content.nu
use ../book.nu
use ../series.nu
use ../film.nu
use ../quote.nu

use ../event_store.nu 
use ../content_store.nu
use ../view.nu 

export def main [
  --at: datetime
  --text-file: path
  --content-files: list<path>
  --book: string
  --series: string
  --film: string
  --title: string
  --author: string
  ...tags: string
]: nothing -> nothing {
  if ($tags | length) < 1 {
    error make 'At least one tag is required'
  }

  let file_path = if $text_file == null {
    let path = '/tmp/quote.md'

    rm --force $path
    touch $path
    hx $path

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
      let ext = ($path | path basename | split row '.' | get 1)
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

  mut title = $title
  mut author = $author
  mut tags = $tags

  if $book != null {
    let book = book rehydrate (event_store fetch book $book)
    $title = $book.title
    $author = $book.author
    $tags = ($tags | prepend book)
  } else if $series != null {
    let series = series rehydrate (event_store fetch series $series)
    $title = $series.title
    $tags = ($tags | prepend series)
  } else if $film != null {
    let film = film rehydrate (event_store fetch film $film)
    $title = $film.title
    $tags = ($tags | prepend film)
  }

  let created = quote new $tags $at --text $text --content $content_ids --title $title --author $author

  event_store store $created

  view update {} $created
}
