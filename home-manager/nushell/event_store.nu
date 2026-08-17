use event.nu

export def from-env []: nothing -> record {
  $env.EVENT_STORE
}

export def new [
  store: closure,
  fetch: closure,
]: nothing -> record {
  {
    store: $store,
    fetch: $fetch
  }
}

export def store [event: record]: any -> nothing {
  let event_store = $in | or-from-env
  do $event_store.store $event
}

export def fetch [aggregate_type: string, aggregate_id?: string]: any -> list<record> {
  let event_store = $in | or-from-env
  do $event_store.fetch $aggregate_type $aggregate_id
}

def or-from-env []: any -> record {
  if ($in | is-empty) {
    from-env
  } else {
    $in
  }
}
