#!/usr/bin/env bash

# DML: No comprobamos que ya se este ejecutando 't-rex'
# [[ `ps aux | grep "./t-rex" | grep -v grep | wc -l` != 0 ]] &&
#  echo -e "${RED}$MINER_NAME miner is already running${NOCOLOR}" &&
#  exit 1

[ -t 1 ] && . colors

. h-manifest.conf

cd $MINER_DIR/$CUSTOM_NAME/$MINER_VER

[[ ! -e ./config.json ]] && echo "No config.json, exiting" && exit 1

#DRV_VERS=`nvidia-smi --help | head -n 1 | awk '{print $NF}' | sed 's/v//' | tr '.' ' ' | awk '{print $1}'`

#if [ ${DRV_VERS} -lt 390 ]; then
#    echo -e "(${RED}Needs driver 396 or higher version${NOCOLOR} compatible)"
#    exit 1
#fi




# DML Ini: Fix 'h-stats.sh'
# Validacion: solo se hace fix, si no se ha realizado previamente
PATH_CUSTOM_H_STAT="$MINER_DIR/h-stats.sh"
if ! grep -q 'DML Ini' "$PATH_CUSTOM_H_STAT"; then

  # Ruta donde se va a crear el fix
  PATH_PARTIAL_SH_FIX_H_STATS="/tmp/add-to-file--h-stats.partial_sh"
  cat << 'EOF' > "$PATH_PARTIAL_SH_FIX_H_STATS"

  # DML Ini
  # Si no tiene $CUSTOM_MINER => necesitamos obtenerlo del wallet.conf
  if [[ -z $CUSTOM_MINER ]]; then
    source /hive-config/wallet.conf
  fi
  # Si no tiene $MINER_API_PORT => necesitamos obtenerlo de $MINER_DIR/$CUSTOM_MINER/h-manifest.conf o lo que es igual: /hive/miners/custom/trexsecondary/h-manifest.conf
  if [[ -z $MINER_API_PORT ]]; then
    source $MINER_DIR/$CUSTOM_MINER/h-manifest.conf
  fi
  # DML Fin
EOF

  # Añade despues de #!/usr/bin/env bash => el fix
  sed -i "/#!\/usr\/bin\/env bash/r $PATH_PARTIAL_SH_FIX_H_STATS" "$PATH_CUSTOM_H_STAT"
fi
# DML Fin: Fix 'h-stats.sh'



t-rex --config config.json 2>&1 #| tee $MINER_LOG_BASENAME.log
