use uuid.nu

export def new [
  text: string,
  content: list<string>,
  tags: list<string>,
  at: datetime,
  --id: string
]: nothing -> record {
  {
    type: 'log_entry.created',
    number: 0,
    aggregate_id: ($id | default (uuid generate)),
    data: {
      text: $text,
      content: $content,
      tags: $tags,
    }
    at: $at,
  }
}

export def rehydrate [events: list<record>]: nothing -> record {
  $events | reduce --fold {} {|event, entry| $entry | apply-event $event} 
}

export def apply-event [event: record]: record -> record {
  match $event.type {
    'log_entry.created' => {
      id: $event.aggregate_id
      text: $event.data.text
      content: $event.data.content
      tags: $event.data.tags
      created_at: $event.at
      updated_at: $event.at
    }

    _ => {
      error make $'Unexpected event type: ($event.type)'
    }
  }
}

export def id []: record -> string {
  $in.id
}

export def content []: record -> list<string> {
  $in.content
}

export def tags []: record -> list<string> {
  $in.tags
}

export def text []: record -> string {
  $in.text
}

export def created-at []: record -> datetime {
  $in.created_at
}
