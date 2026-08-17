use ../book.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  title: string,
  author: string,
  --series: string,
  --at: datetime,
  ...genres: string
]: nothing -> record {
  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let created = book new $title $author $genres $at --series $series 

  event_store store $created
  view update {} $created

  let book = {} | book apply-event $created

  let started = $book | book start $at

  event_store store $started
  view update $book $started

  $book | book apply-event $started
}
