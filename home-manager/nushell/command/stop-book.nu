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

  let stopped = $book | book stop $at --comment $comment

  event_store store $stopped
  view update $book $stopped

  $book | book apply-event $stopped
}
