use ../series.nu

use ../event_store.nu 
use ../view.nu 

export def main [
  season: int
  --create
  --id: string
  --title: string
  --at: datetime
  ...genres: string
]: nothing -> record {
  let at = if ($at == null) {
    date now 
  } else {
    $at
  }

  let series = if $create {
    let created = series new $title $genres $at

    event_store store $created
    view update {} $created

    {} | series apply-event $created
  } else {
    series rehydrate (event_store fetch series $id)
  }

  let season_started = $series | series start $season $at

  event_store store $season_started
  view update $series $season_started

  $series | series apply-event $season_started
}
