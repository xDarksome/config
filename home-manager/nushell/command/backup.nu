export def main [] {
  let secrets = sops decrypt $env.CONFIG_SECRETS_FILE | from yaml

  for $repo in $secrets.restic_repositories.s3 {
    $env.AWS_ACCESS_KEY_ID = $repo.aws_access_key_id
    $env.AWS_SECRET_ACCESS_KEY = $repo.aws_secret_access_key
    $env.RESTIC_REPOSITORY = $'s3:($repo.url)'

    let result = do { restic cat config } | complete

    # Code 10 = repository doesn't exist
    if $result.exit_code == 10 {
        restic init
    } else if $result.exit_code != 0 {
        error make { msg: $result.stderr }
    }

    if $env.LAST_EXIT_CODE == 10 {
      restic init
    }

    restic backup $env.DATA_DIR
  }
}
