use uuid.nu

use log_entry.nu 

export def new [
  title: string,
  genres: list<string>,
  at: datetime,
]: nothing -> record {
  if ($genres | length) < 1 {
    error make 'At least one genre is required'
  }

  {
    type: 'film.created',
    number: 0,
    aggregate_id: (uuid generate),
    data: {
      title: $title,
      genres: $genres,
    }
    at: $at,
  }
}

export def watch [
  score: int,
  at: datetime
  --comment: string,
]: record -> record {
  let self = $in

  if ($score < 0) or ($score > 100) {
    error make 'Score must be in range [0; 100]'
  }

  if $at < $self.created_at {
    error make 'Invalid datetime'
  }

  if ($self.watched_at != null) and ($at < $self.watched_at) {
    error make 'Invalid datetime'
  }

  {
    type: 'film.watched',
    number: ($self.version + 1),
    aggregate_id: $self.id,
    data: {
      score: $score,
      comment: $comment,
    }
    at: $at,
  }
}

export def rehydrate [events: list<record>]: nothing -> record {
  $events | reduce --fold {} {|event, entry| $entry | apply-event $event} 
}

export def apply-event [event: record]: record -> record {
  let self = $in

  let current_version = if $self == {} {
    -1
  } else {
    $self.version
  }

  if $event.number != $current_version + 1 {
      error make 'Invalid event number'
  }

  match $event.type {
    'film.created' => {
      id: $event.aggregate_id
      title: $event.data.title
      genres: $event.data.genres
      score: null,
      comment: null,
      created_at: $event.at
      watched_at: null
      version: $event.number
    }

    'film.watched' => ($self | merge {
      score: $event.data.score
      comment: $event.data.comment
      watched_at: $event.at
      version: $event.number
    })

    _ => {
      error make $'Unexpected event type: ($event.type)'
    }
  }
}

export def log-entry-created-event [event: record]: record -> record {
  let self = $in

  mut text = match $event.type {
    'film.watched' => {
      $'Watched "($self.title)"'
    }

    _ => {
      error make $'Unsupported event type: ($event.type)'
    }
  }

  let comment = $event.data | get -o comment 

  if comment != null {
    $text += $"\n($comment)"
  }

  let id = uuid generate --name $'($event.aggregate_id)-($event.number)'

  log_entry new $text [] [] $event.at --id $id
}
