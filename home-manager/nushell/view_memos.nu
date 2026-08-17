use content/content.nu
use log_entry.nu 
use book.nu 
use series.nu 
use film.nu 
use quote.nu 
use article.nu 

use content_store.nu 
use view.nu

export def new [token: string]: nothing -> record {
  let self = {
    token: $token,
  }

  view new {|aggregate, event| $self | update-view $aggregate $event }
}

def update-view [aggregate: record, event: record]: record -> nothing {
  let self = $in

  match $event.type {
    'log_entry.created' => (
      $self | update-log-entry $aggregate $event
    ),

    'book.created' | 'book.started' | 'book.stopped' | 'book.finished' => (
      $self | update-book $aggregate $event
    ),

    'series.created' | 'series.season_started' | 'series.season_stopped' | 'series.season_finished' => (
      $self | update-series $aggregate $event
    ),

    'film.created' | 'film.watched' => (
      $self | update-film $aggregate $event
    ),

    'quote.created' => (
      $self | update-quote $aggregate $event
    ),

    'article.created' => (
      $self | update-article $aggregate $event
    ),

    _ => { error make $'Unexpected event type: ($event.type)' }
  }
}

def update-log-entry [entry: record, event: record]: record -> nothing {
  let self = $in

  let log_entry = $entry | log_entry apply-event $event

  let id = $log_entry | log_entry id
  let content = $log_entry | log_entry content
  let created_at = $log_entry | log_entry created-at 

  let url = 'http://localhost:5230/api/v1'

  let content_type = 'application/json'
  let headers = {
    Authorization: $'Bearer ($self.token)'
  }

  http delete -e -H $headers $"($url)/memos/($id)"

  let attachments = $content
    | each {|id|
      let content = null | content_store fetch $id
      let type = $content | content type
      http post -t $content_type -H $headers $"($url)/attachments" {
        filename: $'($id).($type | content type file-ext)'
        content: ($content | content bytes | encode base64)
        type: ($type | content type mime)
      }
    }

  let tags = $log_entry.tags
    | each {|tag| $'#($tag)'}
    | str join ' '

  let content = [$tags, $log_entry.text] | str join "\n"

  let body = {
    state: NORMAL
    content: $content
    visibility: PRIVATE
    attachments: $attachments
    createTime: ($log_entry | log_entry created-at | format date "%+")
  }

  let resp = http post -fe -t $content_type -H $headers $"($url)/memos?memoId=($id)" $body
  if $resp.status != 200 {
    $resp | to json | print
  } 
}

def update-book [book: record, event: record]: record -> nothing {
  let self = $in

  if $event.type == 'book.created' {
    return
  }

  $self | update-log-entry {} ($book | book log-entry-created-event $event)
}

def update-series [series: record, event: record]: record -> nothing {
  let self = $in

  if $event.type == 'series.created' {
    return
  }

  $self | update-log-entry {} ($series | series log-entry-created-event $event)
}

def update-film [film: record, event: record]: record -> nothing {
  let self = $in

  if $event.type == 'film.created' {
    return
  }

  $self | update-log-entry {} ($film | film log-entry-created-event $event)
}

def update-quote [quote: record, event: record]: record -> nothing {
  let self = $in

  $self | update-log-entry {} ($quote | quote log-entry-created-event $event)
}


def update-article [article: record, event: record]: record -> nothing {
  let self = $in

  $self | update-log-entry {} ($article | article log-entry-created-event $event)
}
