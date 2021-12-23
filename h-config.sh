#!/usr/bin/env bash

function miner_ver() {
  local MINER_VER=$TREX_VER
  if [[ -z $MINER_VER ]]; then
    MINER_VER=$MINER_LATEST_VER
    [[ ! -z $MINER_LATEST_VER_CUDA11 && $(nvidia-smi --help 2>&1 | head -n 1 | grep -oP "v\K[0-9]+") -ge 455 ]] &&
      MINER_VER=$MINER_LATEST_VER_CUDA11
  fi
  echo $MINER_VER
}

function miner_config_echo() {
  local MINER_VER=`miner_ver`
  miner_echo_config_file "$MINER_DIR/$MINER_VER/config.json"
}

function miner_config_gen() {
  local MINER_CONFIG="$MINER_DIR/$MINER_VER/config.json"
  local TREX_GLOBAL_CONFIG="$MINER_DIR/$MINER_VER/config_global.json"
  mkfile_from_symlink $MINER_CONFIG

  #[[ -z $TREX_ALGO ]] && echo -e "${YELLOW}TREX_ALGO is empty${NOCOLOR}" && return 1
  [[ -z $TREX_TEMPLATE ]] && echo -e "${YELLOW}TREX_TEMPLATE is empty${NOCOLOR}" && return 1
  [[ -z $TREX_URL ]] && echo -e "${YELLOW}TREX_URL is empty${NOCOLOR}" && return 1
  [[ -z $TREX_PASS ]] && TREX_PASS="x"

  local worker=
  if [[ ! -z $TREX_WORKER ]]; then
    worker=$TREX_WORKER
  else
    if [[ $TREX_USER_CONFIG =~ '"worker":' ]]; then
      while read -r line; do
        [[ $line =~ '"worker":' ]] && worker=`echo "{$line}" | jq -r '.worker'`
      done <<< "$TREX_USER_CONFIG"
    fi
  fi

  pools='[]'
  local line=
  local url=
  for line in $TREX_URL; do
      local url=`head -n 1 <<< "$line"`
      grep -q "://" <<< $url
      result=$?
      if [[ -z $TREX_TLS ]]; then
         [[ $result -ne 0 ]] && url="stratum+tcp://${url}"
      else
         [[ $result -ne 0 ]] && url="stratum+ssl://${url}"
      fi

      pool=$(cat <<EOF
{"user": "$TREX_TEMPLATE", "url": "$url", "pass": "$TREX_PASS", "worker": "$worker" }
EOF
)

    pools=`jq --null-input --argjson pools "$pools" --argjson pool "$pool" '$pools + [$pool]'`
  done

  conf=`jq --argfile f1 $TREX_GLOBAL_CONFIG --argjson f2 "$pools" --arg algo "$TREX_ALGO" -n '$f1 | .pools = $f2 | .algo = $algo'`
        [[ $TREX_ALGO =~ "mtp" ]] && conf=$(echo $conf | jq '."validate-shares"=false')

  if [[ -n $TREX_ALGO2 ]]; then
    local worker2=
    if [[ ! -z $TREX_WORKER2 ]]; then
      worker2=$TREX_WORKER2
    else
      if [[ $TREX_USER_CONFIG =~ '"worker2":' ]]; then
        while read -r line; do
          [[ $line =~ '"worker2":' ]] && worker2=`echo "{$line}" | jq -r '.worker2'`
        done <<< "$TREX_USER_CONFIG"
      fi
    fi

    pools2='[]'
    for line in $TREX_URL2; do
        url=`head -n 1 <<< "$line"`
        grep -q "://" <<< $url
        result=$?
        if [[ -z $TREX_TLS2 ]]; then
           [[ $result -ne 0 ]] && url="stratum+tcp://${url}"
        else
           [[ $result -ne 0 ]] && url="stratum+ssl://${url}"
        fi

        pool=$(cat <<EOF
{"user": "$TREX_TEMPLATE2", "url": "$url", "pass": "$TREX_PASS2", "worker": "$worker2" }
EOF
)
      pools2=`jq --null-input --argjson pools2 "$pools2" --argjson pool "$pool" '$pools2 + [$pool]'`
    done

    conf=`jq --argjson f1 "$conf" --argjson f2 "$pools2" -n '$f1 | .pools2 = $f2'`
    if [[ 'octopus|autolykos2|kawpow' =~ "$TREX_ALGO2" ]]; then
      line="{\"lhr-algo\": \"$TREX_ALGO2\"}"
      conf=`jq --null-input --argjson conf "$conf" --argjson line "$line" '$conf + $line'`

      line="{\"lhr-tune\": \"$TREX_INTENSITY\"}"
      conf=`jq --null-input --argjson conf "$conf" --argjson line "$line" '$conf + $line'`
    fi
  fi

  # User defined configuration
  if [[ ! -z $TREX_USER_CONFIG ]]; then
    while read -r line; do
      [[ -z $line ]] && continue
      [[ $line =~ '"worker":' ]] && continue
      conf=`jq --null-input --argjson conf "$conf" --argjson line "{$line}" '$conf + $line'`
    done <<< "$TREX_USER_CONFIG"
  fi

  notes=`echo Generated at $(date)`
  conf=`jq --null-input --argjson conf "$conf" --arg notes "$notes" -n '$conf | ._notes = $notes'`

  api='{"api-bind-http": "0.0.0.0:'$MINER_API_PORT'"}'
  conf=`jq --null-input --argjson conf "$conf" --argjson api "$api" -n '$conf + $api'`

  echo "$conf" > $MINER_CONFIG
}
