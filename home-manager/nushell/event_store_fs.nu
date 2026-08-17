use ./event_store.nu
use ./event.nu

export def new [dir: path]: nothing -> record {
  (event_store new
    {|event| store $dir $event}
    {|agg_type, agg_id?| fetch $dir $agg_type $agg_id}
  )
}

def store [dir: path, event: record]: nothing -> nothing {
  let agg_type = $event | event aggregate-type
  let agg_id = $event | event aggregate-id
  let event_number = $event | event number

  let dir_path = [$dir, $agg_type, $agg_id] | path join  

  mkdir $dir_path

  let file_path = [$dir_path, $'($event_number).json'] | path join 
  $event | to json | save $file_path
}

def fetch [dir: path, agg_type: string, agg_id?: string]: nothing -> list<record> {
  let base_path = if $agg_id == null {
    [$dir, $agg_type] | path join
  } else {
    [$dir, $agg_type, $agg_id] | path join
  }

  let pattern = if $agg_id == null {
    [$base_path, "*", "*.json"] | path join
  } else {
    [$base_path, "*.json"] | path join
  }

  glob ($pattern | into glob) --no-dir
  | each { |file| fix-datetime-fields (open $file) }
  | sort-by { |event| [$event.aggregate_id, $event.number] }
}

# Nushell de-serializes datetime strings into `string`, not `datetime`.
def fix-datetime-fields [event: record]: nothing -> record {
  let fields = (
    $event
    | columns
    | where { |f| $f == "at" or ($f | str ends-with "_at") }
  )

  $event | update cells --columns $fields { |value| $value | into datetime }
}
