export def generate [
  --name: string  
]: nothing -> string {
  if ($name | is-empty) {
    uuidgen
  } else {
    uuidgen --sha1 --namespace=@oid --name $name
  }
}
