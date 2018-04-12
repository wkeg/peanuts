#Script to install vmtools, runs on initial boot

if [  -f /usr/bin/vm-support ];
then
     break;
else
     mkdir test
     chmod 777 ./test
     mount <file_system> ./test
     ./test/vmware-tools-distrib/vmware-install.pl -d
     umount ./test
     rmdir ./test
fi
