export def main [
  domain: string,
  --master-password: string,
  --length: int = 32,
  --expose
  --clipboard
] {
  let master_password = if $master_password != null {
    $master_password
  } else {
    print "Master password: "
    if $expose { input } else { input -s }
  }

  let secret = echo $master_password | argon2 $domain -d -t 16 -k 16777216 -p 16 -l $length -r -v 13

  if $clipboard {
     $secret | wl-copy -n -o
  } else {
     return $secret   
  }
}
