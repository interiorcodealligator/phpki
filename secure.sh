#! /bin/bash

owner="`id -nu`"

cat <<EOM

This application is designed to be an easy to use "certificate factory"
requiring minimum human intervention to administer.  It is intended for
use within a trusted INTRAnet for the creation and management of x.509
e-mail digital certificates by departmental managers.  IT IS NOT INTENDED
FOR USE OVER THE INTERNET.

This application stores private keys within a sub-directory, making them
potentially susceptible to compromise.  Extra care has been taken in the
design of this application to protect the security of your certificates,
on the condition that you INSTALL IT AS THE ROOT USER.  However, no
software is 100% secure.  

Please run this script from INSIDE the application folder and AFTER running setup.php.

EOM

read -p "Enter the location of your PHPki password [/etc/phpkipasswd]: " passwd_file
passwd_file=${passwd_file:-"/etc/phpkipasswd"}

if [[ ! -f "$passwd_file" ]]
then
    echo "The file you specified does not yet exist."
    echo "Let's create it and add your first user."
    echo
    read -p "Enter a user id: " user_id

    echo "Creating the $user_id user account..."

    htpasswd -c -m "$passwd_file" "$user_id" || exit

    echo "Creating the administrator account..."
	echo "See the README file for more information about the"
	echo "'pkiadmin' user."
    htpasswd -m "$passwd_file" 'pkiadmin' || exit
fi

if [[ ! "${owner}_" = "root_" ]]
then
	cat <<EOM
YOU ARE NOT LOGGED ON AS ROOT!

If you choose to proceed anyway, and you plan to make this application
available over the Internet, you increase the risk of compromising the
security of your certifcates and your server.  

This script may not run correctly if you are not the ROOT user.
EOM
fi

echo
echo -n "Enter the user ID your web server runs as (apache, www-data etc.) [www-data]: " ; read -r x
echo
echo -n "Enter the group ID your web server runs as (apache, www-data etc.) [www-data]: " ; read -r z
echo
echo "Enter the IP or subnet address [192.168.0.0/16] which will be allowed access"
echo -n "to the user admin module in under ./admin: " ; read -r y

user=${x:-"www-data"}
group=${z:-"www-data"}
subnet=${y:-'192.168.0.0/16'}
subnet="${subnet} 127.0.0.1"

echo
echo "Writing htaccess files..."

for i in ./include; do
	echo "deny from all" >$i/.htaccess
done 

cat <<EOS >> ./ca/.htaccess
AuthName "Restricted Area"
AuthType Basic
AuthUserFile "$passwd_file"
require valid-user
#SSLRequireSSL
php_flag magic_quotes_gpc off

EOS

cat <<EOS > ./admin/.htaccess 
AuthName "Restricted Area"
AuthType Basic
AuthUserFile "$passwd_file"
require valid-user
#SSLRequireSSL
Order Allow,Deny
Allow from $subnet
php_flag magic_quotes_gpc off

EOS

echo
echo "Writing permissions to PHPki web directory..."

# Start with web server getting read-only access to everything.
# Directories have sticky bits set.
find .           -exec chown $owner:$group {} \;
find .   -type l -exec chown -h $owner:$group {} \;
find . ! -type d -exec chmod 640 {} \;
find .   -type d -exec chmod 3750 {} \;

# Display file list with new permissions
list_files=`ls -la .`
echo "$list_files"

echo
echo "Now we will secure the storage directory."
read -p "Please enter storage directory path [/var/www/phpki-store]: " -r storage_dir
storage_dir=${storage_dir:-"/var/www/phpki-store"}

# Secure the storage directory

# Check if other users are in the web server group
another_user=`egrep ^${group} '/etc/group' | awk -F':' '{print $4}'`
if [[ $another_user ]]; then
	echo "Warning: There are other users in the ${group} group and they will get the same group permissions, make sure that's intentional."
fi

find $storage_dir           -exec chown $user:$group {} \;
find $storage_dir   -type l -exec chown -h $user:$group {} \;
find $storage_dir ! -type d -exec chmod 700 {} \;
find $storage_dir   -type d -exec chmod 700 {} \;

# TODO see if these permissions work better:
# chown -R -- $owner:$group $storage_dir
# chmod -R 770 -- $storage_dir/CA
# chmod -R 770 -- $storage_dir/tmp
# chmod -R 740 -- $storage_dir/config

echo
echo "Writing permissions to PHPki storage directory..."
echo
# Display file list with new permissions
list_files=`ls -la ${storage_dir}`
echo "$list_files"
echo
echo "All done."
