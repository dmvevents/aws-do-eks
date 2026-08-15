#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

export CMD=""

case "${MANIFEST_TYPE}" in
	deployment|lws|lws-2pp|lws-pp2|lws-pp|lws-ep-pd|dgd)
		cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml
		export CMD="kubectl apply -f ./${MANIFEST_TYPE}.yaml"
		;;
	lws-ep)
		# Removed from disagg/: that permutation renders ONE `vllm serve` with no
		# prefill/decode split and no --kv-transfer-config, i.e. it is AGGREGATED. It now
		# lives only in ../agg. Named arm rather than falling through to *) so a stale
		# MANIFEST_TYPE=lws-ep in someone's .env says what to do instead.
		echo "MANIFEST_TYPE=lws-ep is not valid in disagg/ - that topology is aggregated; use ../agg (MANIFEST_TYPE=lws-ep)."
		echo "For expert parallelism WITH a prefill/decode split use MANIFEST_TYPE=lws-ep-pd."
		;;
	*)
		echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"
		;;
esac

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: list everything this deployment created (empty until pods schedule)
kubectl -n ${NAMESPACE} get deploy,lws,dgd,svc,pods -l app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null
