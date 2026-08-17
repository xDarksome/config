use ../book.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  score: int
  --id: string
  --comment: string
  --at: datetime
]: nothing -> record {
  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let book = book rehydrate (event_store fetch book $id)

  let finished = $book | book finish $score $at --comment $comment

  event_store store $finished
  view update $book $finished

  $book | book apply-event $finished
}
