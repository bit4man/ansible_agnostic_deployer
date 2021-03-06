#!/bin/bash

END_PROJECT_NUM=1
START_PROJECT_NUM=1
LOG_FILE=/tmp/ilt_provision_

for var in $@
do
    case "$var" in
        --HOST_GUID=*) HOST_GUID=`echo $var | cut -f2 -d\=` ;;
        --START_PROJECT_NUM=*) START_PROJECT_NUM=`echo $var | cut -f2 -d\=` ;;
        --END_PROJECT_NUM=*) END_PROJECT_NUM=`echo $var | cut -f2 -d\=` ;;
        -h) HELP=true ;;
        -help) HELP=true ;;
    esac
done

function ensurePreReqs() {
    if [ "x$HOST_GUID" == "x" ]; then
            echo -en "must pass parameter: --HOST_GUID=<ocp host GUID> . \n\n"
            help
            exit 1;
    fi

    LOG_FILE=$LOG_FILE$START_PROJECT_NUM-$END_PROJECT_NUM.log
    echo -en "starting\n\n" > $LOG_FILE

    echo -en "\n\nProvision log file found at: $LOG_FILE\n";
}

function help() {
    echo -en "\n\nOPTIONS:";
    echo -en "\n\t--HOST_GUID=*             REQUIRED: specify GUID of target OCP environment)"
    echo -en "\n\t--START_PROJECT_NUM=*     OPTIONAL: specify # of first OCP project to provision (defult = 1))"
    echo -en "\n\t--END_PROJECT_NUM=*       OPTIONAL: specify # of OCP projects to provision (defualt = 1))"
    echo -en "\n\t-h                        this help manual\n\n"
}


function login() {

    echo -en "\nHOST_GUID=$HOST_GUID\n" >> $LOG_FILE
    oc login https://master.$HOST_GUID.openshift.opentlc.com -u opentlc-mgr -p r3dh4t1! >> $LOG_FILE
}


function executeLoop() {

    echo -en "\nexecuteLoop() START_PROJECT_NUM = $START_PROJECT_NUM ;  END_PROJECT_NUM=$END_PROJECT_NUM" >> $LOG_FILE

    for (( c=$START_PROJECT_NUM; c<=$END_PROJECT_NUM; c++ ))
    do
        GUID=$c
        OCP_USERNAME=user$c
        executeAnsible
    done
}

function executeAnsible() {
    TARGET_HOST="bastion.$HOST_GUID.openshift.opentlc.com"
    SSH_USERNAME="jbride-redhat.com"
    SSH_PRIVATE_KEY="id_ocp"

    # NOTE:  Ensure you has ssh'd (as $SSH_USERNMAE) into the bastion node of your OCP cluster environment at $TARGET_HOST and logged in using opentlc-mgr account:
    #           oc login https://master.$HOST_GUID.openshift.opentlc.com -u opentlc-mgr

    WORKLOAD="ocp-workload-fuse-ignite"
    POSTGRESQL_MEMORY_LIMIT=512Mi
    PROMETHEUS_MEMORY_LIMIT=255Mi
    META_MEMORY_LIMIT=1Gi
    SERVER_MEMORY_LIMIT=2Gi
    PROJECT_PREFIX=fi

    GUID=$PROJECT_PREFIX$GUID

    echo -en "\n\nexecuteAnsible():  Provisioning project with GUID = $GUID and OCP_USERNAME = $OCP_USERNAME\n" >> $LOG_FILE

    ansible-playbook -i ${TARGET_HOST}, ./configs/ocp-workloads/ocp-workload.yml \
                 -e"ansible_ssh_private_key_file=~/.ssh/${SSH_PRIVATE_KEY}" \
                 -e"ansible_ssh_user=${SSH_USERNAME}" \
                    -e"ANSIBLE_REPO_PATH=`pwd`" \
                    -e"ocp_username=${OCP_USERNAME}" \
                    -e"ocp_workload=${WORKLOAD}" \
                    -e"guid=${GUID}" \
                    -e"ocp_user_needs_quota=true" \
                    -e"ocp_domain=$HOST_GUID.openshift.opentlc.com" \
                    -e"POSTGRESQL_MEMORY_LIMIT=$POSTGRESQL_MEMORY_LIMIT" \
                    -e"PROMETHEUS_MEMORY_LIMIT=$PROMETHEUS_MEMORY_LIMIT" \
                    -e"META_MEMORY_LIMIT=$META_MEMORY_LIMIT" \
                    -e"SERVER_MEMORY_LIMIT=$SERVER_MEMORY_LIMIT" \
                    -e"ACTION=create" >> $LOG_FILE
}

ensurePreReqs
login
executeLoop

