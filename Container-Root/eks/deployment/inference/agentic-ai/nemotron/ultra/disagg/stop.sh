#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

# 1. Delete the declared resources for the selected manifest type.
case "${MANIFEST_TYPE}" in
	deployment|lws|lws-2pp|lws-pp2|lws-pp|lws-ep-pd|dgd)
		cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml
		export CMD="kubectl delete -f ./${MANIFEST_TYPE}.yaml --ignore-not-found"
		;;
	lws-ep)
		# Removed from disagg/ (aggregated topology; it lives in ../agg now). Resources from
		# an earlier lws-ep run in THIS namespace are still cleaned: step 2 below sweeps
		# everything labelled app.kubernetes.io/part-of=${DEPLOYMENT_NAME} regardless of type.
		echo "MANIFEST_TYPE=lws-ep is not valid in disagg/ (aggregated; see ../agg). Sweeping by label instead."
		export CMD=""
		;;
	*)
		echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"
		export CMD=""
		;;
esac

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# 2. Sweep by label: catches resources from a previous MANIFEST_TYPE, edited yamls,
#    or operator-generated children - kubectl delete -f alone leaves those behind.
#    Everything this stack creates carries app.kubernetes.io/part-of=${DEPLOYMENT_NAME}.
export CMD="kubectl -n ${NAMESPACE} delete dgd,lws,deploy,sts,svc,pods --selector app.kubernetes.io/part-of=${DEPLOYMENT_NAME} --ignore-not-found"
if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# 3. Wait for pod termination, then verify zero residue (should print nothing).
kubectl -n ${NAMESPACE} wait --for=delete pods --selector app.kubernetes.io/part-of=${DEPLOYMENT_NAME} --timeout=180s 2>/dev/null
echo ""
echo "Verifying teardown (the following should be empty):"
kubectl -n ${NAMESPACE} get dgd,lws,deploy,sts,svc,pods --selector app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null
echo "Done."
