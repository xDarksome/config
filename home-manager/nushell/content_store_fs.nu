use ./content_store.nu
use ./content/content.nu

export def new [dir: path]: nothing -> record {
  (content_store new
    {|content| store $dir $content}
    {|content_id| fetch $dir $content_id}
  )
}

def store [dir: path, content: record]: nothing -> nothing {
  let content_id = $content | content id
  let content_dir_path = content-dir-path $dir $content_id
  mkdir $content_dir_path

  let content_file_ext = $content | content type | content type file-ext
  let content_file_path = [$content_dir_path, $'.($content_file_ext)'] | path join 
  $content | content bytes | save --force $content_file_path
}

def fetch [dir: path, content_id: string]: nothing -> record {
  let dir_path = content-dir-path $dir $content_id

  let file = ls $dir_path -a | first
  if ($file == null) {
    return null
  }

  let file_path = [$dir_path, $file.name] | path join
  let bytes = open --raw $file_path | collect | into binary

  let file_ext = $file.name | split row '.' | get 1

  let type = content type from-file-ext $file_ext

  content new $bytes $type
}

def content-dir-path [dir: path, content_id: string]: nothing -> path {
  [$dir, $content_id] | path join  
}
