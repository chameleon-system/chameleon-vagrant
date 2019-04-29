
# chameleon-vagrant
Vagrantfile to bootstrap a chameleon system using docker and docker-compose on a vanilla ubuntu base

## Prerequisites
Vagrant has to be installed on your computer

## Installation
After cloning this repo onto your machine you can adjust the contents of "Vagrantfile" to match a port that is usable on your system. Please note, that you have to be root when starting Vagrant if you want to use the default ports 80 and 443.

Enter "vagrant up" in your shell.

In case you have more than one network interface you will be asked to which of them the virtual machine should be bound. Usually that's the first one.

The installation process will take several minutes. After the vagrant bootstrapping the chameleon installation process will be started.

If everything works as expected you should see a shell output like this:

    default: Starting vagrant bootstrap.sh script. Detailed log info can be found within the vagrant guest in /var/log/chameleon-install.log
    default: Step [1/6] - Installing docker...
    default: Step [2/6] - Installing docker-compose...
    default: Step [3/6] - Installing chameleon sources...
    default: Step [4/6] - Launching docker-compose application stack...
    default: Step [5/6] - Installing composer packages...
    default: Step [6/6] - Importing database and mediapool...
    default: Ready! You should now be able to access chameleon at the given hostname. Remember restrictions for privileged ports!

**After that you should be able to access the System.**
https://localhost:3443/ (FrontEnd)
https://localhost:3443/cms (BackEnd). User: admin Password: adminadminadmin

## Troubleshooting

 - Q: I get a warning recarding an invalid certificate when accessing the page via https. 
 - A: This is okay since you are connecting to "localhost" where we can't provide a valid certificate for out of the box. You can ignore the warning for testing and evaluation purposes
 - Q: I can access the page via https://localhost but not via https://<My IP Address/
 - A: Since chameleon is a domain name aware system, all domain names other than "localhost" have to be configured in the backend prior to using them.
 - Q: Something else went wrong and I'm not reachign Step 6/6 as shown above
 - A: Enter the VM using "vagrant ssh", Switch to root using "sudo su -" and check the log as mentioned above using "less /var/log/chameleon-install.log"
