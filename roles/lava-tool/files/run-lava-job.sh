#!/bin/bash
# 2016 Alexander Couzens <lynxis@fe80.eu>
# 2018 Alexander Couzens <lynxis@fe80.eu>
# GPLv2

# optional envs:
#
# LAVA_USER
# LAVA_URL
#
# required envs:
#
# JOB_NAME - set the name of the job
# IMAGE_URL - url to the an image (e.g. produced by jenkins)
# TEMPLATE_FILE - path to the lava job template

if [ -z "$LAVA_URL" ] ; then
	if [ -z "$LAVA_USER" ] ; then
		LAVA_USER="$USER"
	fi
	LAVA_URL="https://$LAVA_USER@lava.fe80.eu/RPC2"
fi

if [ -z "$JOB_NAME" ] ; then
	echo "You need to define a job name $JOB_NAME"
	exit -1
fi
if [ -z "$IMAGE_URL" ] ; then
	echo "You need to define a url $IMAGE_URL"
	exit -1
fi

if [ -z "$TEMPLATE_FILE" ] ; then
	echo "You need to define a $TEMPLATE_FILE"
	exit -1
fi

jenkins_message() {
	echo "=================================="
	echo "== $@"
	echo "=================================="
}

job_done() {
	local jobid="$1"
	lava-tool job-status "$LAVA_URL" $jobid |egrep -q '(Complete|Incomplete|Canceled|Canceling)'
}

job_template() {
	# job_name will show up on the webinterface
	# filename is the local file name on the machien
	# coreboot_url is the url from where lava will download the image
	local job_name="$1"
	local file_name="$2"
	local image_url="$3"
	sed "s!IMAGE_URL!${image_url}!g" "$TEMPLATE_FILE" | \
		sed "s!JOB_NAME!${job_name}!g" > "$file_name"
}

job_submit() {
	# submit a job by using a template
	local file_name=$1
	lava-tool submit-job "$LAVA_URL" "$file_name"
}

job_status() {
	# return 0 = SUCESSFUL
	# return 1 = Incomplete
	# return 125 = unknown error
	local jobid="$1"
	local status
	status="$(lava-tool job-status "$LAVA_URL" "$jobid" |grep '^Job Status:')"
	if [ $? -ne 0 ] ; then
		# can not get job status
		return 125
	fi
	status=$(echo "$status" | awk -F': ' '{print $2}')
	case "$status" in
		"Complete")
			return 0
			;;
		"Incomplete")
			return 1
			;;
		*)
			# Submitted|Running|Canceled|Canceling
			return 125
			;;
	esac
}

# job_template: $job_name $filename $IMAGE_URL
job_template "$JOB_NAME" "job.yml" "$IMAGE_URL"
JOB_ID=$(job_submit "job.yml" | awk -F': ' '{print $2}')
if [ $? -ne 0 ] || [ -z "$JOB_ID" ] ; then
	jenkins_message "ERROR: Could not create the lava job"
	exit 1
fi

jenkins_message "created job $JOB_ID - $LAVA_URL/scheduler/job/$JOB_ID"

echo "wait until job $JOB_ID is done"
while ! job_done "$JOB_ID" ; do
	echo -n .
	sleep 1
done

job_status "$JOB_ID"
exit $?
