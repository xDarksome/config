const RESTIC_DOMAIN = 'restic__'
const SOPS_AGE_DOMAIN = 'sops_age'

export def main [
  --expose
] {
  print "Master password: "
  let master_password = if $expose { input } else { input -s }

  mkdir $env.SECRETS_DIR

  let restic_password_file = $env.RESTIC_PASSWORD_FILE
  let sops_age_key_file = $env.SOPS_AGE_KEY_FILE

  print 'Deriving restic password...'
  derive-secret --master-password $master_password $RESTIC_DOMAIN | save $restic_password_file
  print $'Restic password written to ($restic_password_file)'

  print 'Deriving SOPS age identity...'
  derive-secret --master-password $master_password $SOPS_AGE_DOMAIN
    | python ([$env.CONFIG_DIR python/hex-to-age-identity.py] | path join)
    | save $sops_age_key_file
  print $'SOPS age identity written to ($sops_age_key_file)' 
}

