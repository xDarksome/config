use log_entry.nu 
use book.nu 
use series.nu 
use film.nu 
use quote.nu 
use article.nu 

use view.nu

export def new [dir: path]: nothing -> record {
  {
    dir: $dir,
  }
}

export def upcast []: record -> record {
  let self = $in
  view new {|aggregate, event| $self | update-view $aggregate $event }
}

export def query [aggregate_type: string]: record -> list<record> {
  let self = $in

  match $aggregate_type {
    'book' => (glob ($self.dir + '/books/*')) 
    'series' => (glob ($self.dir + '/series/*')) 

    _ => { error make $'Unexpected aggregate type: ($aggregate_type)' }
  }
    | par-each { |path| open $path }
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

  let entry = $entry | log_entry apply-event $event

  let subdir_path = $entry.created_at | format date '%Y/%m/%d'
  let dir_path = [$self.dir, 'log', $subdir_path] | path join

  let time_prefix = $entry.created_at | format date "%H:%M:%S"

  let file_name = $'($time_prefix)-($entry.id).md'
  let file_path = [$dir_path, $file_name] | path join

  let frontmatter = {
    id: $entry.id
    content: $entry.content
    tags: $entry.tags
  }

  let markdown = [
    '---'
    ($frontmatter | to yaml | str trim)
    '---'
    ''
    ($entry.text)
    ''
  ] | str join "\n"

  mkdir $dir_path
  $markdown | save -f $file_path
}

def update-book [book: record, event: record]: record -> nothing {
  let self = $in

  let book = $book | book apply-event $event

  if $event.type != 'book.created' {
    ($self | update-log-entry {} ($book | book log-entry-created-event $event))
  }

  let dir_path = [$self.dir, 'books'] | path join
  mkdir $dir_path
  
  let file_path = [$dir_path, ($book.id + '.json')] | path join
  $book | to json | save -f $file_path
}

def update-series [series: record, event: record]: record -> nothing {
  let self = $in

  let series = $series | series apply-event $event

  if $event.type != 'series.created' {
    ($self | update-log-entry {} ($series | series log-entry-created-event $event))
  }

  let dir_path = [$self.dir, 'series'] | path join
  mkdir $dir_path
  
  let file_path = [$dir_path, ($series.id + '.json')] | path join
  $series | to json | save -f $file_path
}

def update-film [film: record, event: record]: record -> nothing {
  let self = $in

  let film = $film | film apply-event $event

  if $event.type != 'film.created' {
    ($self | update-log-entry {} ($film | film log-entry-created-event $event))
  }

  let dir_path = [$self.dir, 'films'] | path join
  mkdir $dir_path
  
  let file_path = [$dir_path, ($film.id + '.json')] | path join
  $film | to json | save -f $file_path
}

def update-quote [quote: record, event: record]: record -> nothing {
  let self = $in

  let quote = $quote | quote apply-event $event

  $self | update-log-entry {} ($quote | quote log-entry-created-event $event)

  let dir_path = [$self.dir, 'quotes'] | path join
  mkdir $dir_path
  
  let file_path = [$dir_path, ($quote.id + '.json')] | path join
  $quote | to json | save -f $file_path
}

def update-article [article: record, event: record]: record -> nothing {
  let self = $in

  let article = $article | article apply-event $event

  $self | update-log-entry {} ($article | article log-entry-created-event $event)

  let dir_path = [$self.dir, 'articles'] | path join
  mkdir $dir_path
  
  let file_path = [$dir_path, ($article.id + '.json')] | path join
  $article | to json | save -f $file_path
}
