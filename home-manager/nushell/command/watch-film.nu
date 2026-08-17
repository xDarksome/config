use ../film.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  title: string
  score: int
  --at: datetime
  --comment: string
  ...genres: string
]: nothing -> record {
  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let created = film new $title $genres $at

  event_store store $created
  view update {} $created

  let film = {} | film apply-event $created

  let watched = $film | film watch $score $at --comment $comment

  event_store store $watched
  view update $film $watched

  $film | film apply-event $watched
}
