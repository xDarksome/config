use uuid.nu

use log_entry.nu 

export def new [
  title: string,
  author: string,
  genres: list<string>,
  at: datetime,
  --series: string,
]: nothing -> record {
  if ($genres | length) < 1 {
    error make 'At least one genre is required'
  }

  {
    type: 'book.created',
    number: 0,
    aggregate_id: (uuid generate),
    data: {
      title: $title,
      author: $author,
      series: $series,
      genres: $genres,
    }
    at: $at,
  }
}

export def start [at: datetime]: record -> record {
  if $at < $in.created_at {
    error make 'Invalid datetime'
  }

  {
    type: 'book.started',
    number: ($in.version + 1),
    aggregate_id: $in.id,
    at: $at,
  }
}

export def stop [
  at: datetime,
  --comment: string,
]: record -> record {
  if $in.finished_at != null {
      error make 'Already finished'
  }

  if $in.stopped_at != null {
      error make 'Already stopped'
  }

  if $at < $in.started_at {
    error make 'Invalid datetime'
  }

  {
    type: 'book.stopped',
    number: ($in.version + 1),
    aggregate_id: $in.id,
    data: {
      comment: $comment,
    }
    at: $at,
  }
}

export def finish [
  score: int,
  at: datetime,
  --comment: string,
]: record -> record {
  if ($score < 0) or ($score > 100) {
      error make 'Score must be in range [0; 100]'
  }

  if $in.finished_at != null {
      error make 'Already finished'
  }

  if $in.stopped_at != null {
      error make 'Already stopped'
  }

  if $at < $in.started_at {
    error make 'Invalid datetime'
  }

  {
    type: 'book.finished',
    number: ($in.version + 1),
    aggregate_id: $in.id,
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
  let current_version = if $in == {} {
    -1
  } else {
    $in.version
  }

  if $event.number != $current_version + 1 {
      error make 'Invalid event number'
  }

  match $event.type {
    'book.created' => {
      id: $event.aggregate_id
      author: $event.data.author
      title: $event.data.title
      series: $event.data.series
      genres: $event.data.genres
      score: null,
      created_at: $event.at
      started_at: null
      stopped_at: null
      finished_at: null
      version: $event.number
    }

    'book.started' => ($in | merge {
      started_at: $event.at
      stopped_at: null
      finished_at: null
      version: $event.number
    })

    'book.stopped' => ($in | merge {
      score: $event.data.score
      stopped_at: $event.at
      version: $event.number
    })

    'book.finished' => ($in | merge {
      score: $event.data.score
      finished_at: $event.at
      version: $event.number
    })

    _ => {
      error make $'Unexpected event type: ($event.type)'
    }
  }
}

export def log-entry-created-event [event: record]: record -> record {
  let self = $in

  let series = if $in.series != null {
    $" \(($self.series)\)"
  } else {
    ''
  }

  mut text = match $event.type {
    'book.started' => {
      $'Started reading "($self.title)" by ($self.author)' + $series
    }

    'book.stopped' => {
      $'Stopped reading "($self.title)" by ($self.author)' + $series
    }

    'book.finished' => {
      $'Finished reading "($self.title)" by ($self.author)' + $series
    }

    _ => {
      error make $'Unsupported event type: ($event.type)'
    }
  }

  let comment = $event | get -o data | get -o comment 

  if comment != null {
    $text += $"\n($comment)"
  }

  let id = uuid generate --name $'($event.aggregate_id)-($event.number)'

  log_entry new $text [] [] $event.at --id $id 
}

export def id []: record -> string {
  $in.id
}

