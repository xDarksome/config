use uuid.nu

use log_entry.nu 

export def new [
  source: string,
  text: string
  tags: list<string>
  at: datetime
]: nothing -> record {
  if ($tags | length) < 1 {
    error make 'At least one tag is required'
  }

  {
    type: 'article.created',
    number: 0,
    aggregate_id: (uuid generate),
    data: {
      text: $text
      source: $source
      tags: $tags
    }
    at: $at,
  }
}

export def rehydrate [events: list<record>]: nothing -> record {
  $events | reduce --fold {} {|event, entry| $entry | apply-event $event} 
}

export def apply-event [event: record]: record -> record {
  let current_version = if $in == {} {
    -1
  } else {
    $in.version
  }

  if $event.number != $current_version + 1 {
      error make 'Invalid event number'
  }

  match $event.type {
    'article.created' => {
      id: $event.aggregate_id
      text: $event.data.text
      source: $event.data.source
      tags: $event.data.tags
      created_at: $event.at
      version: $event.number
    }

    _ => {
      error make $'Unexpected event type: ($event.type)'
    }
  }
}

export def log-entry-created-event [event: record]: record -> record {
  let self = $in

  mut text = match $event.type {
    'article.created' => {
      [$event.data.source, $event.data.text] | str join "\n\n"
    }

    _ => {
      error make $'Unsupported event type: ($event.type)'
    }
  }

  let tags = $event.data.tags | prepend 'article'

  let id = uuid generate --name $'($event.aggregate_id)-($event.number)'

  log_entry new $text [] $tags $event.at --id $id
}
