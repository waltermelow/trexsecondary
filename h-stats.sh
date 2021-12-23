#!/usr/bin/env bash

#algo_avail=("balloon" "bcd" "bitcore" "c11" "hmq1725" "hsr" "lyra2z" "phi" "polytimos" "renesis" "sha256t" "skunk" "sonoa" "timetravel" "tribus" "x16r" "x16s" "x17")

stats_raw=`curl --silent --connect-timeout 2  --max-time $API_TIMEOUT localhost:${MINER_API_PORT}/summary`
#stats_raw=`cat /hive/miners/t-rex/stats.lhr`

if [[ $? -ne 0 || -z $stats_raw ]]; then
	echo -e "${YELLOW}Failed to read miner stats from localhost:${MINER_API_PORT}${NOCOLOR}"
else
	#echo "$stats_raw" | jq -c .`echo ${gpuerr[*]} | tr ' ' ';'`
	local gpu_worked=`echo "$stats_raw" | jq '.gpus[].gpu_user_id'`
	local gpu_busid=(`cat /var/run/hive/gpu-detect.json | jq -r '.[] | select(.brand=="nvidia") | .busid' | cut -d ':' -f 1`)
	local busids=()
	local gpuerr= # rejected and invalid shares per GPU
	dpkg --compare-versions `echo "$stats_raw" | jq -r '.version'` "lt" "0.20.0"
	if [[ $? -eq 0 ]]; then
		gpuerr=()
		local idx=0
		for i in $gpu_worked; do
			gpu=${gpu_busid[$i]}
			busids[idx]=$((16#$gpu))
			gpuerr[idx]=$(jq --arg gpu "$i" '.stat_by_gpu[$gpu|tonumber].invalid_count' <<< "$stats_raw")
			idx=$((idx+1))
		done
	else
		gpuerr=`echo "$stats_raw" | jq -r '.gpus[].shares.invalid_count'`
		gpuerr=${gpuerr//null/0}
	fi

	local bus_numbers=[]
	dpkg --compare-versions `echo "$stats_raw" | jq -r '.version'` "lt" "0.19.10"
	if [[ $? -eq 0 ]]; then
		bus_numbers=`echo ${busids[@]}  | jq -cs '.'`
	else
		bus_numbers=`echo "$stats_raw" | jq '.gpus[].pci_bus' | jq -cs '.'`
	fi

	# total hashrate in khs
	khs=$(jq ".hashrate/1000" <<< "$stats_raw")

	local stats_dual=`echo $stats_raw | jq -r '.dual_stat'`
	if [[ $stats_dual != 'null' && $stats_dual != '' ]]; then
		khs2=$(jq ".hashrate/1000" <<< "$stats_dual")
		local gpuerr2=`echo "$stats_dual" | jq -r '.gpus[].shares.invalid_count'`
		gpuerr2=${gpuerr2//null/0}
		stats=$(jq --argjson bus_numbers "$bus_numbers" \
		           --arg gpuerr "`echo ${gpuerr[*]} | tr ' ' ';'`" \
		           --arg gpuerr2 "`echo ${gpuerr2[*]} | tr ' ' ';'`" \
		           --arg total_khs "$khs" --arg total_khs2 "$khs2" \
		'{ hs: [.gpus[].hashrate], hs_units: "hs", temp: [.gpus[].temperature], fan: [.gpus[].fan_speed], uptime: .uptime,
		   ar: [.accepted_count, .rejected_count, .invalid_count, $gpuerr], $bus_numbers, algo: .algorithm, ver: .version,
		   hs2:[.dual_stat.gpus[].hashrate], hs_units2: "hs", ar2: [.dual_stat.accepted_count, .dual_stat.rejected_count,
		   .dual_stat.invalid_count, $gpuerr2], algo2: .dual_stat.algorithm, $total_khs, $total_khs2 }' <<< "$stats_raw")

	else
		stats=$(jq --argjson bus_numbers "$bus_numbers" \
		           --arg gpuerr "`echo ${gpuerr[*]} | tr ' ' ';'`" \
		           --arg total_khs "$khs" \
		'{ hs: [.gpus[].hashrate], hs_units: "hs", temp: [.gpus[].temperature], fan: [.gpus[].fan_speed], uptime: .uptime,
		   ar: [.accepted_count, .rejected_count, .invalid_count, $gpuerr], $bus_numbers, algo: .algorithm, ver: .version,
		   $total_khs }' <<< "$stats_raw")
	fi
fi

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
