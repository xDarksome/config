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
    type: 'series.created',
    number: 0,
    aggregate_id: (uuid generate),
    data: {
      title: $title,
      genres: $genres,
    }
    at: $at,
  }
}

export def start [season: int, at: datetime]: record -> record {
  let self = $in

  if $season < 1 {
    error make 'Invalid season'
  }

  if $self.current_season != null {
    error make $'Watching season ($self.current_season)'
  }

  if $at < $self.created_at {
    error make 'Invalid datetime'
  }

  {
    type: 'series.season_started',
    number: ($self.version + 1),
    aggregate_id: $self.id,
    data: {
      season: $season
    }
    at: $at,
  }
}

export def stop [
  season: int,
  at: datetime
  --comment: string,
]: record -> record {
  let self = $in

  if $self.current_season == null {
    error make $'Not watching'
  }

  if $season != $self.current_season {
    error make $'Watching season ($self.current_season)'
  }

  let current_season = $self.seasons | get $'($self.current_season)'

  if $at < $current_season.started_at {
    error make 'Invalid datetime'
  }

  {
    type: 'series.season_stopped',
    number: ($self.version + 1),
    aggregate_id: $self.id,
    data: {
      season: $season
      comment: $comment,
    }
    at: $at,
  }
}

export def finish [
  season: int,
  score: int,
  at: datetime
  --comment: string,
]: record -> record {
  let self = $in

  if $self.current_season == null {
    error make $'Not watching'
  }

  if $season != $self.current_season {
    error make $'Watching season ($self.current_season)'
  }

  let current_season = $self.seasons | get $'($self.current_season)'

  if $at < $current_season.started_at {
    error make 'Invalid datetime'
  }

  if ($score < 0) or ($score > 100) {
    error make 'Score must be in range [0; 100]'
  }

  {
    type: 'series.season_finished',
    number: ($self.version + 1),
    aggregate_id: $self.id,
    data: {
      season: $season,
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
    'series.created' => {
      id: $event.aggregate_id
      title: $event.data.title
      genres: $event.data.genres
      seasons: {},
      current_season: null,
      score: null,
      created_at: $event.at
      version: $event.number,
    }

    'series.season_started' => {
      $self | merge {
        seasons: ($self.seasons | upsert $'($event.data.season)' {
          started_at: $event.at
          stopped_at: null,
          finished_at: null,
          score: null,       
        })
        current_season: $event.data.season
        version: $event.number,
      }
    }

    'series.season_stopped' => {
      $self | merge {
        seasons: ($self.seasons | update $'($event.data.season)' {|_|
            $in | update stopped_at $event.at
        })
        current_season: null,
        version: $event.number,
      }
    }

    'series.season_finished' => {
      $self | merge {
        seasons: ($self.seasons | update $'($event.data.season)' {|_|
            $in | update finished_at $event.at | update score $event.data.score
        })
        current_season: null,
        score: $event.data.score
        version: $event.number,
      }
    }

    _ => {
      error make $'Unexpected event type: ($event.type)'
    }
  }
}

export def log-entry-created-event [event: record]: record -> record {
  let self = $in

  mut text = match $event.type {
    'series.season_started' => {
      $'Started watching "($self.title)" S($event.data.season)'
    }

    'series.season_stopped' => {
      $'Stopped watching "($self.title)" S($event.data.season)'
    }

    'series.season_finished' => {
      $'Finished watching "($self.title)" S($event.data.season)'
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
