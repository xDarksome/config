use ./event_store.nu 

export def from-env []: nothing -> record {
  $env.VIEW
}

export def new [
  update: closure,
]: nothing -> record {
  {
    update: $update,
  }
}

export def update [aggregate: record, event: record]: any -> nothing {
  let view = $in | or-from-env

  $view | each {|v| do $v.update $aggregate $event}
}

def or-from-env []: any -> record {
  if ($in | is-empty) {
    from-env
  } else {
    $in
  }
}
