use uuid.nu

use log_entry.nu 

export def new [
  tags: list<string>
  at: datetime
  --text: string
  --content: list<string>
  --title: string
  --author: string
]: nothing -> record {
  if ($tags | length) < 1 {
    error make 'At least one tag is required'
  }

  if ($text | is-empty) and ($content | is-empty) {
    error make 'At least one of `text` or `content` is required'
  }

  if ($title | is-empty) and ($author | is-empty) {
    error make 'At least one of `title` or `author` is required'
  }

  {
    type: 'quote.created',
    number: 0,
    aggregate_id: (uuid generate),
    data: {
      text: $text
      content: $content
      title: $title
      author: $author
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
    'quote.created' => {
      id: $event.aggregate_id
      text: $event.data.text
      content: $event.data.content
      title: $event.data.title
      author: $event.data.author
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
    'quote.created' => {
      mut text = ''
      mut source = []
  
      if not ($event.data.text | is-empty) {
         $text = ($event.data.text
            | lines
            | each { |line| $'> ($line)' }
            | str join "\n")
      }

      if not ($event.data.author | is-empty) {
        $source = $source | append $event.data.author
      }

      if not ($event.data.title | is-empty) {
        $source = $source | append $'"($event.data.title)"'
      }

      $text + $"\n\n" + ($source | str join ', ')
    }

    _ => {
      error make $'Unsupported event type: ($event.type)'
    }
  }

  let content = $event.data.content | default []
  let tags = $event.data.tags | prepend 'quote'

  let id = uuid generate --name $'($event.aggregate_id)-($event.number)'

  log_entry new $text $content $tags $event.at --id $id
}
