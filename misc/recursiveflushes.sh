# $FreeBSD$

#
# Copyright (c) 2008 Peter Holm <pho@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD$
#

# test recursive flushes in bdwrite().

[ `id -u ` -ne 0 ] && echo "Must be root!" && exit 1

. ../default.cfg

snap() {
   for i in `jot 5`; do
      mksnap_ffs $1 $2
      [ $? -eq 0 ] && break
   done
}

mount | grep $mntpoint | grep -q /dev/md && umount -f $mntpoint
mdconfig -l | grep -q md$mdstart &&  mdconfig -d -u $mdstart
mdconfig -a -t swap -s 4g -u $mdstart || exit 1
bsdlabel -w md$mdstart auto
newfs $newfs_flags md${mdstart}$part > /dev/null
mount /dev/md${mdstart}$part $mntpoint

old=`sysctl vfs.recursiveflushes | awk '{print $NF}'`
cd $mntpoint
rm -f $mntpoint/.snap/pho.*
snap $mntpoint $mntpoint/.snap/pho.1
snap $mntpoint $mntpoint/.snap/pho.2
snap $mntpoint $mntpoint/.snap/pho.3
snap $mntpoint $mntpoint/.snap/pho.4
snap $mntpoint $mntpoint/.snap/pho.5

for i in `jot 32`; do
   # Create 32 Mb files
   dd if=/dev/zero of=big.$i bs=16k count=2048 2>&1 | egrep -v "records|transferred"&
done
for i in `jot 32`; do
   wait
done
for i in `jot 32`; do
   rm -f big.$i
done

rm -f $mntpoint/.snap/pho.*
new=`sysctl vfs.recursiveflushes | awk '{print $NF}'`
[ $old != $new ] && echo "vfs.recursiveflushes changed from $old to $new"

cd /
while mount | grep $mntpoint | grep -q /dev/md; do
	umount $mntpoint || sleep 1
done
mdconfig -d -u $mdstart
