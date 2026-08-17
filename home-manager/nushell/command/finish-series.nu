use ../series.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  season: int
  score: int
  --id: string
  --comment: string
  --at: datetime,
]: nothing -> record {
  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let series = series rehydrate (event_store fetch series $id)

  let season_finished = $series | series finish $season $score $at --comment $comment

  event_store store $season_finished
  view update $series $season_finished

  $series | series apply-event $season_finished
}
