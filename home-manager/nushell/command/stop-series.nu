use ../series.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  season: int
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

  let season_stopped = $series | series stop $season $at --comment $comment

  event_store store $season_stopped
  view update $series $season_stopped

  $series | series apply-event $season_stopped
}
