#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /distribution/rebuild
#   Description: The test performs rebuild of given component
#   Author: Martin Kyral <mkyral@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh

COMPONENT=${COMPONENT:-""}
BUILDUSER="rebuild-$COMPONENT"
rlIsRHEL '>=8' && PARAMS='--nobest'

rlJournalStart
    rlPhaseStartSetup
        rlLog "::: Rebuilding '$COMPONENT' :::"
        if ! [ -f /usr/share/restraint/plugins/completed.d/90-rollback-pkg-transaction ] ; then
            rlRun "rlImport 'distribution/RpmSnapshot'"
            rlRun "RpmSnapshotCreate"
        fi
        rlRun "useradd $BUILDUSER"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    if [ -n "$COMPONENT" ] ; then
        rlPhaseStartTest "Install"
            # install component
            rlRun "yum  --enablerepo='*' install -y $COMPONENT"
            # fetch srpm
            rlRun "rlFetchSrcForInstalled $COMPONENT || yumdownloader --enablerepo='*' --source $COMPONENT" \
                    0 "Fetching the source rpm"
            # deal with build requires
            rlRun "chmod 755 $COMPONENT*src.rpm"
            # install srpm
            rlRun "cp $COMPONENT*src.rpm ~$BUILDUSER"
            rlRun "chown $BUILDUSER:users ~$BUILDUSER/$COMPONENT*src.rpm"
            rlRun "rpm -i --nodeps $COMPONENT*src.rpm" \
                    0 "Installing the source rpm"
            rlRun "yum-builddep --enablerepo='*' --disablerepo=*-source $PARAMS -y ~/rpmbuild/SPECS/${COMPONENT}.spec"
        rlPhaseEnd

        rlPhaseStartTest "Rebuild"
            rlRun "su -c 'rpmbuild --rebuild ~/$COMPONENT*src.rpm' $BUILDUSER" \
                    0 "Rebuilding the source rpm"
        rlPhaseEnd
    else
        rlPhaseStartTest "Nothing"
            rlFail "No component provided, nothing to do"
        rlPhaseEnd
    fi

    rlPhaseStartCleanup
        rlRun "killall -u $BUILDUSER" 0,1
        sleep 5
        rlRun "userdel -rf $BUILDUSER" 
        if ! [ -f /usr/share/restraint/plugins/completed.d/90-rollback-pkg-transaction ] ; then
            rlRun "RpmSnapshotRevert"
        fi
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
