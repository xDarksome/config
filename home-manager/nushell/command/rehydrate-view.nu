use ../log_entry.nu 
use ../book.nu 
use ../series.nu 
use ../film.nu
use ../quote.nu
use ../article.nu

use ../event_store.nu 
use ../view.nu 

export def main []: nothing -> nothing {
  rehydrate log_entry {|event| log_entry apply-event $event}

  rehydrate book {|event| book apply-event $event}

  rehydrate series {|event| series apply-event $event}

  rehydrate film {|event| film apply-event $event}

  rehydrate quote {|event| quote apply-event $event}

  rehydrate article {|event| article apply-event $event}
}

def rehydrate [
  aggregate_type: string,
  apply_fn: closure
]: nothing -> nothing {
  event_store fetch $aggregate_type
    | group-by aggregate_id
    | values
    | par-each {|events|
      $events | reduce --fold {} {|event, agg|
        {} | view update $agg $event
        $agg | (do $apply_fn $event) 
      }
    }
} 
