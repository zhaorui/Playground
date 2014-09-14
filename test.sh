############################################################
# Function:     GetHomeDir
# Parameter:    User name
# Return:       Path to home directory, or nothing if can't find.
# Description:
#   Locates user's home directory from NSS data.

GetHomeDir()
{
    # The home directory is the 6th field in the NSS data.
    getent passwd "$1" | cut -d : -f 6
    Flag=1
    if [ $Flag -eq 1 ]
    then
        echo Flag == 1
    fi
}

#Main Sub
main()
{
    GetHomeDir bill
}


ls
echo Args: $1 $2 $3 ... $#

ARG1=$1
ARG2=$2
ret_val1=${ARG1:-"arg1_default"}
ret_val2=${ARG2:="arg2_default"}

echo ARG1: $ARG1 ARG2: $ARG2 retval1: $ret_val1 retval2: $ret_val2

main

