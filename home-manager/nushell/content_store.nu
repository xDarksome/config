use content/content.nu 

export def from-env []: nothing -> record {
  $env.CONTENT_STORE
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

export def store [content: record]: any -> nothing {
  let content_store = $in | or-from-env
  do $content_store.store ($content | content validate)
}

export def fetch [content_id: string]: any -> record {
  let content_store = $in | or-from-env
  do $content_store.fetch $content_id
}

def or-from-env []: any -> record {
  if ($in | is-empty) {
    from-env
  } else {
    $in
  }
}
