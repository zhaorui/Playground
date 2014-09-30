#!/bin/sh /usr/share/centrifydc/perl/run

##############################################################################
#
# Copyright (C) 2014 Centrify Corporation. All rights reserved.
#
# Mac-specific script to mount shared folders.
#
# This script runs once at user login by LaunchAgent
# /Library/LaunchAgents/com.centrify.loginmount.plist.
#
#  This script gets network shares from LaunchAgent, use ldapsearch to get
#  user's homeDirectory attribute, uses AppleScript to mount shares, then
#  creates symlinks to all mounted (and accessible) netowrk shares in
#  "Network Shares" folder on user's desktop, and optionally adds the folder
#  on user's dock.
#
#  This script cleans up old symlinks first, then check adclient status. If
#  adclient is not in connected mode, this script will do nothing.
#
# 
#  This mapper supports smb/afp/nfs share. Share format can be the following:
#    smb://sever/share
#    smb://server/share/subdir
#    smb://user:password@server/share
#    smb://user:@server/share
#    afp://server/share
#    nfs://server/share
#  
#  This mapper also supports the use of environment variables at shares.
#  The mapper will look for keys such as $USER and $HOME, and substitute
#  the corresponding environment variable value into the path.  Please
#  see array @g_env_vars for supported environment variables
#
#  Example:
#    smb://server/share/$USER => smb://server/share/user1
#    smb://server/share/$HOME => smb://server/share//Users/user1
#
# Parameters: username mount_windowshome create_dock_icon create_alias [share ...]
#   username            username
#   mount_windowshome   mount Windows home? (1: yes | 0 or undef: no)
#   create_dock_icon    create Dock icon? (1: yes | 0 or undef: no)
#   create_alias        create alias instead of symlink? (1: yes | 0 or undef: no)
#   share               share list
#
# Exit value:
#   0   Normal
#   1   Error
#   2   usage
#
##############################################################################

use strict;

use lib '/usr/share/centrifydc/perl';

use File::Basename qw(basename);
use File::Path qw(rmtree);
use URI::Split qw(uri_split);

use CentrifyDC::GP::Mac qw(:objc CF_INTEGER ToCF ToString GetMacOSVersionString CompareVersion);
use CentrifyDC::GP::General qw(:debug RunCommand RunCommandWithTimeout IsEmpty ChangeOwner WriteFile CreateDir);
use CentrifyDC::GP::DirectoryAccess qw(GetAttribute GetQueryInfo);
use CentrifyDC::GP::Plist;
use CentrifyDC::GP::MacDefaults qw(DEFAULTS_ARRAY_ADD);

my $ADINFO = '/usr/bin/adinfo';
my $MOUNT = '/sbin/mount';

my $SYMLINK_DIR = 'Network Shares';
my $PLIST_DOCK = 'com.apple.dock';

my $MAX_RETRY = 5;
my $TIMEOUT_MOUNT = 20;     # timeout for mount command
my $TIMEOUT_REFRESH = 20;   # timeout for refresh desktop/dock
my $TIMEOUT_ALIAS = 5;      # timeout for creating alias

my $MACVER;

my $g_dir_userhome;
my $g_dir_symlink;

my @g_env_vars = qw(
    HOME
    USER
);

sub IsConnected();
sub TrimURL($);

sub GetHomeDirectoryProperty($);
sub GetHomeURL($);
sub GetPaths($);
sub GetAvailableFileName($);
sub GetRealSharePath($);
sub CreateSymlink($$$);

sub MountShares($);
sub RefreshDesktop();
sub RefreshDock();

sub CreateDesktopIcons($$);
sub CreateDockIcon($);
sub CreateAlias($$);

sub Map($$$$$);



# >>> SUB >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#
# check if adclient is in connected mode
#
#   return: 1   - connected
#           0   - not connected or cannot get adclient status.
#
sub IsConnected()
{
    TRACE_OUT("Check if adclient is connected");

    # we don't want adinfo hang forever, so only give it 60 seconds
    my ($rc, $output) = RunCommandWithTimeout("$ADINFO -m", 60);

    my $connected = 0;

    if (defined($rc) and $rc eq '0' and defined($output))
    {
        chomp($output);
        ($output eq 'connected') and $connected = 1;
    }

    DEBUG_OUT("adclient is %s", $connected ? 'connected' : 'not connected');

    return $connected;
}

#
# trim share url, convert \ to /, replace space with %20, remove trailing /
#
#   $_[0]:  share url
#
#   return: string  - trimmed share rul
#           undef   - failed
#
sub TrimURL($)
{
    my $url = $_[0];
    defined($url) or return undef;

    $url =~ s|\\|/|g;   # replace \ with /
    $url =~ s|/+$||g;   # remove trailing /

    return $url;
}

#
# Get user's homeDirectory property
# Need to notice the following:
#  1. user may not be in the joined domain, for example in a trusted domain
#  2. for the above reason, need to use user's credential to do ldapsearch
#
#   $_[0]:  username
#
#   return: string  - homeDirectory property. empty string means this property
#                     doesn't exist.
#           undef   - failed
#
sub GetHomeDirectoryProperty($)
{
    my $user = $_[0];

    defined($user) or return undef;

    TRACE_OUT("Get homeDirectory property of user [$user]");

    my $userinfo = GetQueryInfo('user', $user);

    if (! defined($userinfo))
    {
        ERROR_OUT("Cannot query user $user");
        return undef;
    }

    # need to get the following info:
    #  - canonicalName (to calculate ldapuri and searchbase)
    #  - userPrincipalName
    my $user_cn = $userinfo->{canonicalName};
    my $user_upn = $userinfo->{userPrincipalName};
    if (! defined($user_cn))
    {
        ERROR_OUT("Cannot get canonicalName of user [$user]");
        return undef;
    }
    if (! defined($user_upn))
    {
        ERROR_OUT("Cannot get userPrincipalName of user [$user]");
        return undef;
    }

    $user_cn =~ m|^([^/]+)|;
    my $user_domain = $1;
    if (! defined($user_domain) || $user_domain eq '')
    {
        ERROR_OUT("Cannot extract user domain from canonicalName");
        return undef;
    }
    my $user_domain_dn = $user_domain;
    $user_domain_dn = "DC=" . $user_domain_dn;
    $user_domain_dn =~ s/\./,DC=/g;

    my $ldapuri = "ldap://$user_domain";
    my $filter = "&(objectclass=user)(userPrincipalName=$user_upn)";

    my ($ret, $homeDirectory) = GetAttribute($user, undef, $ldapuri, $user_domain_dn, $filter, 'homeDirectory');
    if (! $ret)
    {
        ERROR_OUT("Cannot get user's local home directory");
        return undef;
    }

    defined($homeDirectory) or $homeDirectory = '';

    TRACE_OUT("homeDirectory property of user $user: [%s]", $homeDirectory);

    return $homeDirectory;
}

#
# Get user's Windows home URL
#
#   $_[0]:  username
#
#   return: string  - the homeDirectory URL (in smb://server/share format)
#                     empty string means user has no homeDirectory
#           undef   - failed
#
sub GetHomeURL($)
{
    my $user = $_[0];

    defined($user) or return undef;

    my $homedir = GetHomeDirectoryProperty($user);
    defined($homedir) or return undef;

    my $homeURL = '';

    if ($homedir ne '')
    {
        $homedir = TrimURL($homedir);
        $homeURL = "smb:" . $homedir;
        DEBUG_OUT("User's Windows home URL: [%s]", $homeURL);
    }
    else
    {
        DEBUG_OUT("User's Windows home URL is empty");
    }

    return $homeURL;
}

#
# Get all required file/dir paths (global variables) based on username
#
#   $_[0]:  username
#
#   return: 1       - successful
#           undef   - failed
#
sub GetPaths($)
{
    my $user = $_[0];

    if (! defined($user))
    {
        ERROR_OUT("User not defined");
        return undef;
    }

    $g_dir_userhome = (getpwnam($user))[7];
    if (! defined($g_dir_userhome))
    {
        ERROR_OUT("Cannot get home dir of user [$user]");
        return undef;
    }

    $g_dir_symlink = "$g_dir_userhome/Desktop/$SYMLINK_DIR";

    return 1;
}

#
# Get available file name. If it doesn't exist, return; if it exists, then try
# $file_1, $file_2, ...
#
#   $_[0]:  file
#
#   return: string  - file name (full path)
#           undef   - failed
#
sub GetAvailableFileName($)
{
    my $file = $_[0];

    defined($file) or return undef;

    my $ret = $file;

    if (-e $ret)
    {
        my $retry = 1;
        while ($retry < $MAX_RETRY)
        {
            $ret = $file . "_$retry";
            (! -e $ret) && last;
            $retry++;
        }
    }

    return $ret;
}

#
# Get Real Share Path
#
# This function check if the network share path obtained from the GP
# registry contain any environment variable.  If so, substitute the 
# actual environment variable value into the path, and return it.
# NOTE: only support the environment variable listed at @g_env_vars
#
#   $_[0]:  network share path
#
#   return: string - network share path with environment variable substituted
#
sub GetRealSharePath($)
{
    my $share = $_[0];
    
    foreach my $var (@g_env_vars)
    {
        if ( exists($ENV{$var}) )
        {
            $share =~ s|\$$var|$ENV{$var}|g;
        }
        else
        {
            DEBUG_OUT("Environment variable [\$$var] is not defined.");
        }
    }
    return $share;
}

#
# Create symbolic link from given path
#
#   $_[0]:  path
#   $_[1]:  symlink_path
#   $_[2]:  create alias instead of symlink? (1: yes | 0 or undef: no)
#
#   return: 1       - successful
#           undef   - failed
#
sub CreateSymlink($$$)
{
    my $path = $_[0];
    my $symlink_path = $_[1];
    my $create_alias = $_[2];

    my $rc;

    if ($create_alias)
    {
        DEBUG_OUT("Create alias for [%s] inside [%s]", $path, $g_dir_symlink);
        eval
        {
            $rc = CreateAlias($path, $g_dir_symlink);
        };
        if (! defined($rc))
        {
            ERROR_OUT("cannot create alias for [%s]", $path);
            return undef;
        }
    }
    else
    {
        $symlink_path = GetAvailableFileName($symlink_path);
        
        DEBUG_OUT("Create symlink [%s] for [%s]", $symlink_path, $path);
        eval
        {
            $rc = symlink($path, $symlink_path);
        };
        if ($@ || ! $rc)
        {
            ERROR_OUT("cannot create symlink:  src: [%s]  dest: [%s]", $path, $symlink_path);
            return undef;
        }
    }
    return 1;
}

#
# Mount share
#
#
# We don't use mount command because:
#  1. on Mac 10.6, if you mount a share using mount command, unplug network
#     cable and logout, the logout can take several minutes
#  2. on Mac 10.5, mount command doesn't support Windows 2008 Server
#
# Using AppleScript not only solves the above problem, but it also works
# for DFS share on Mac 10.7.
#
#   $_[0]:  array reference of shares
#
#   return: 1       - successful
#           undef   - failed
#
sub MountShares($)
{
    my $shares = $_[0];

    if (! defined($shares) or ref($shares) ne 'ARRAY')
    {
        ERROR_OUT("Incorrect share list");
        return undef;
    }

    my $ret = 1;

    my $afp_var = int(GetAFPTimer());
    if (! defined($afp_var))
    {
        $afp_var = 600;
    }
    # if the timer was originally even lower than 35 then we don't
    # need to replace that variable
    if ($afp_var > 35)
    {
        ChangeAFPTimer(35);
    }
    foreach my $share (@$shares)
    {
        DEBUG_OUT("Mount share: [%s]", $share);

        my ($scheme, $auth, $path) = uri_split($share);
        my ($userinfo, $server) = $auth =~ m/(.*)([^@]+)/;

        my $mountpoint = basename($share);
        $mountpoint =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;
        $mountpoint = "/Volumes/".$mountpoint;
        $mountpoint = GetAvailableFileName($mountpoint);
        mkdir $mountpoint;
        
        my $username = $share;
        $username =~ s|^.*//(.*)@$|$1|;

        my $cmd;
        if ($scheme eq "smb")
        {
            $cmd = "mount_smbfs \"$share\" \"$mountpoint\"";
        }
        elsif ($scheme eq "afp")
        {

            $cmd = "mount_afp \"$share\" \"$mountpoint\"";
        }
        elsif ($scheme eq "nfs")
        {
            my $sharepoint = $share;
            $sharepoint =~ s/nfs:\/\///;
            $sharepoint =~ s/\//:\//;
            $cmd = "mount \"$sharepoint\" \"$mountpoint\"";
        }
        else
        {
            #Impossible to get here, because URL is be checked when user
            #input it to the line editor at windows side.
            ERROR_OUT("protocol of mount URL is not right.");
            $ret = undef;
            next;
        }
        my $rc = RunCommandWithTimeout($cmd, $TIMEOUT_MOUNT);
        if (! defined($rc) || $rc ne '0')
        {
            ERROR_OUT("cannot mount share [%s]. skip.", $share);
            $ret = undef;
            next;
        }
    }
    # change the afptimer variable back to it's original state
    ChangeAFPTimer($afp_var);

    return $ret;
}

#
# Refresh desktop icons
#
#
sub RefreshDesktop()
{
    DEBUG_OUT("Refresh desktop icons");

    my $cmd = "/usr/bin/osascript -e '
    tell application \"Finder\"
        update every item with necessity
    end tell
    '";

    RunCommandWithTimeout($cmd, $TIMEOUT_REFRESH);
}

#
# Refresh dock
#
#
sub RefreshDock()
{
    DEBUG_OUT("Refresh dock");

    my $cmd = "/usr/bin/osascript -e '
    quit application \"Dock\"
    '";
    
    RunCommandWithTimeout($cmd, $TIMEOUT_REFRESH);
}

#
# Create desktop icons for all mounted network shares in
# ~user/Desktop/Network Shares
#
#   $_[0]:  array reference of network shares information from GP
#   $_[1]:  create alias instead of symlink? (1: yes | 0 or undef: no)
#
#   return: 1       - successful
#           undef   - failed
#
sub CreateDesktopIcons($$)
{
    my $gp_ref = $_[0];
    my $create_alias = $_[1];

    if (! defined($gp_ref) or ref($gp_ref) ne 'ARRAY')
    {
        ERROR_OUT("Incorrect share list");
        return undef;
    }
    
    DEBUG_OUT("Create desktop icons for network share");

    my @gp_shares;
    #
    # Network shares from GP is expected to have format such as
    # "smb://username:passwd@server/share". Loop below will trim 
    # all "afp:", "smb:", "nfs:" prefix and the "username:passwd@"
    # info, and add a trailing slash in the network share path.
    # The resultant network share path will become
    # "//server/share/"
    #
    foreach my $tmp (@$gp_ref)
    {
        $tmp =~ s/^(smb|afp|nfs):\/\///;
        $tmp =~ s|^[^@]*@||;
        $tmp = "//$tmp/";
        push(@gp_shares, $tmp);
    }

    if (! CreateDir($g_dir_symlink))
    {
        ERROR_OUT("Cannot create symlink dir [%s]", $g_dir_symlink);
        return undef;
    }

    my ($rc, $out) = RunCommandWithTimeout($MOUNT, $TIMEOUT_MOUNT);
    if (! defined($rc) || $rc ne '0')
    {
        ERROR_OUT("mount command failed");
        return undef;
    }

    my @lines = split(/\n/, $out);

    foreach my $line (@lines)
    {
        chomp $line;
        if ($line =~ m/^(.*) on (.*) \((smbfs|afpfs|nfs),/)
        {
            my $share = $1;
            my $mntpoint = $2;
            my $mapped = 0;

            # share is in //username@server/share format. remove username@
            $share =~ s|^//[^@]*@||;
            $share = "//$share/";
            
            # in mount command output, special characters are encoded, for
            # example space character is encoded as %20. need to decode these
            # encoded character.
            $share =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;
            
            DEBUG_OUT("Found mounted network share [%s] [%s]", $share, $mntpoint);
            if (! -r $mntpoint)
            {
                DEBUG_OUT("[%s] is not readable. skip", $mntpoint);
                next;
            }

            # loop through network share paths from GP registry and create
            # desktop shortcut according to the mount point mapping
            foreach my $gp_share (@gp_shares)
            {
                if ($gp_share =~ m/^\Q$share\E/)
                {
                    $mapped = 1;
                    my $src = "";
                    my $dest = "$g_dir_symlink/".basename($gp_share);
                    
                    TRACE_OUT("gp_share: $gp_share, destination path: $dest");
                    
                    # extract network share path and paste to the mount point
                    # to form the real path
                    #
                    # Fix for bug 62151
                    # Mount mechanism for network share is changed from 10.9, hence
                    # this script require version specific code to handle this.
                    #
                    if ((CompareVersion($MACVER, '10.9.*') >= 0 && ($line =~ m/^.* on .* \(smbfs,/)) ||
                        ($line =~ m/^.* on .* \(nfs,/))
                    {
                    	if ($gp_share eq $share)
                    	{
                            $src = $mntpoint;
                            CreateSymlink($src, $dest, $create_alias);
                        }
                        else
                        {
                            TRACE_OUT("gp_share: $gp_share not equal to share: $share");
                        }
                    }
                    else
                    {
                        $gp_share =~ m/^\Q$share\E(.*)\/$/;
                        $src = "$mntpoint/$1";
                        if (-e $src)
                        {
                            CreateSymlink($src, $dest, $create_alias);
                        }
                    }				
                }
            }
            if (!$mapped)
            {
                # For OS X 10.6 & 10.7 afp mount point information will give info like "//afp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                # There is no way network share path can be mapped with such information given
                # Hence only the mount point symlink will be created if such situation is met
                #
                DEBUG_OUT("Unable to map network share from [$share]. Symlink of the corresponding mount point will be created.");
                CreateSymlink($mntpoint, "$g_dir_symlink/".basename($mntpoint), $create_alias);
            }
        }
    }

    RefreshDesktop();

    return 1;
}

#
# Create a dock icon for network share symlink dir ~user/Desktop/Network Shares.
#
# This function takes 10 secs to run.
#
# Sometimes restarting dock will discard any previous changes made to the dock
# plist file, so need to restart dock, wait for a while, then check if dock
# icon still exists.
#
#   $_[0]:  user
#
#   return: 1       - successful
#           undef   - failed
#
sub CreateDockIcon($)
{
    my $user = $_[0];

    defined($user) or return undef;

    DEBUG_OUT("Create dock icon for network share");

    my $plist = CentrifyDC::GP::Plist->new($PLIST_DOCK);
    if (! $plist)
    {
        ERROR_OUT("Cannot create plist instance. user: [$user]  plist: [$PLIST_DOCK]");
        return undef;
    }

    my $plist_file = $plist->filename();

    if (! $plist->load())
    {
        ERROR_OUT("Cannot load plist [%s]", $plist_file);
        return undef;
    }

    my $found = 0;

    my $icon_string = $SYMLINK_DIR;
    my $icon_url_string = $g_dir_symlink;
    my $icon_url_type = 0;
    (defined $MACVER) or $MACVER = GetMacOSVersionString(3);
    if (CompareVersion($MACVER, '10.7.2') >= 0)
    {
        #
        # since 10.7.2, dock icon entry format changed from
        #   /Users/username/Desktop/Network Shares
        # to
        #   file://localhost/Users/username/Desktop/Network%20Shares/
        # also, _CFURLStringType changed from 0 to 15.
        #
        $icon_string =~ s/ /%20/g;
        $icon_url_string =~ s/ /%20/g;
        $icon_url_string = "file://localhost" . $icon_url_string;
        $icon_url_type = 15;
    }

    my $array_current_icons = CreateArrayFromNSArray($plist->get(['persistent-others']), 1);

    foreach my $icon (@$array_current_icons)
    {
        my $folder = '';
        eval
        {
            $folder = $icon->{'tile-data'}{'file-data'}{_CFURLString};
        };
        if ($@)
        {
            next;
        }

        if ($folder =~ m |Desktop/${icon_string}[/]*$|)
        {
            DEBUG_OUT("Found symlink folder [%s]", $folder);
            $found = 1;
            last;
        }
    }

    if ($found)
    {
        TRACE_OUT("Dock icon already exists");
        return 2;
    }

    my $dict = {
                    'tile-data' => {
                        'file-data' => {
                            '_CFURLString'      => "$icon_url_string/",
                            '_CFURLStringType'  => ToCF($icon_url_type, CF_INTEGER),
                        },
                        'file-label' => 'Network Shares',
                    },
                    'tile-type' => 'directory-tile',
                };
    
    my $defaults_dock = CentrifyDC::GP::MacDefaults->new($PLIST_DOCK);
    if (!$defaults_dock)
    {
        ERROR_OUT("Cannot create MacDefaults object for defaults write operation!");
        return undef;
    }

    my $rc = $defaults_dock->write('persistent-others', DEFAULTS_ARRAY_ADD, $dict);
    if (!defined($rc) or $rc ne '1')
    {
        ERROR_OUT("MacDefaults write cannot modify $PLIST_DOCK.");
        return undef;
    }

    RefreshDock();

    # wait for a while and see if dock icon is still there
    sleep 10;

    if (! $plist->load())
    {
        ERROR_OUT("Cannot load plist [%s]", $plist_file);
        return undef;
    }

    $found = 0;

    $array_current_icons = CreateArrayFromNSArray($plist->get(['persistent-others']), 1);

    foreach my $icon (@$array_current_icons)
    {
        my $folder = '';
        eval
        {
            $folder = $icon->{'tile-data'}{'file-data'}{_CFURLString};
        };
        if ($@)
        {
            next;
        }

        if ($folder =~ m |Desktop/${icon_string}[/]*$|)
        {
            TRACE_OUT("Dock icon exists", $folder);
            $found = 1;
            last;
        }
    }

    if ($found)
    {
        TRACE_OUT("Dock icon created successfully");
        return 1;
    }
    else
    {
        TRACE_OUT("Dock icon not created");
        return undef;
    }

}

#
# Create alias to a folder
#
#
#   $_[0]:  source folder
#   $_[1]:  folder that alias will be created inside
#
#   return: 1       - successful
#           undef   - failed
#
sub CreateAlias($$)
{
    my $src = $_[0];
    my $dest_folder = $_[1];

    if (! defined($src) or ! defined($dest_folder))
    {
        ERROR_OUT("Cannot create alias: source or destination not specified.");
        return undef;
    }

    if ($src eq '' or $dest_folder eq '')
    {
        ERROR_OUT("Cannot create alias: source or destination cannot be empty string.");
        return undef;
    }

    my $ret = 1;

    my $cmd = "/usr/bin/osascript -e '
        tell application \"Finder\"
            set src to POSIX file \"$src\" as text
            set dest to POSIX file \"$dest_folder\" as text
            make new alias file to folder src at folder dest
        end tell
    '";

    my $rc = RunCommandWithTimeout($cmd, $TIMEOUT_ALIAS);
    if (! defined($rc) || $rc ne '0')
    {
        ERROR_OUT("cannot create alias for [%s].", $src);
        $ret = undef;
    }

    return $ret;
}

#
# map
#
#   $_[0]:  username
#   $_[1]:  mount windows home? (1: yes | 0 or undef: no)
#   $_[2]:  create Dock icon? (1: yes | 0 or undef: no)
#   $_[3]:  create alias instead of symlink? (1: yes | 0 or undef: no)
#   $_[4]:  array reference of network shares
#
#   return: 1       - successful
#           undef   - failed
#
sub Map($$$$$)
{
    my ($user, $mount_windowshome, $create_dock_icon, $create_alias, $shares) = @_;

    if (! defined($user))
    {
        ERROR_OUT("User not specified");
        return undef;
    }

    if (! IsConnected())
    {
        DEBUG_OUT("adclient is not connected. Skip automount.");
        return 1;
    }

    # get user's windows home
    if ($mount_windowshome)
    {
        my $homeURL = GetHomeURL($user);
        if (defined($homeURL) && $homeURL ne '')
        {
            DEBUG_OUT("Add share: [%s]", $homeURL);
            push(@$shares, $homeURL);
        }
        else
        {
            DEBUG_OUT("Cannot get Windows home of user [$user]. skip.");
        }
    }

    if (! IsEmpty($shares))
    {
        my $rc = MountShares($shares);
        if (! defined($rc))
        {
            DEBUG_OUT("At least 1 mount command failed.");
        }
    }
    else
    {
        DEBUG_OUT("No share to mount");
        return 1;
    }

    my $rc = CreateDesktopIcons($shares, $create_alias);
    if (! defined($rc))
    {
        DEBUG_OUT("Fail to create desktop icons for mounted network shares");
        return undef;
    }

    if (! $create_dock_icon)
    {
        return 1;
    }

    # try to create dock icon until it's actually created or reaches max retry
    my $created = 0;
    my $retry = 1;
    while ($retry < $MAX_RETRY)
    {
        $rc = CreateDockIcon($user);
        if ($rc)
        {
            $created = 1;
            last;
        }
        $retry++;
    }

    if ($created)
    {
        DEBUG_OUT("Dock icon created.");
    }
    else
    {
        DEBUG_OUT("Fail to create dock icon");
    }

    return 1;
}

# This function changes the afp_reconnect_max_time variable value under /Library/Preferences.
# It is by default set to 600 seconds and this will be used for AFP shares mounted through the 
# cmdline. When disconnected on logout, the process will hang on this afp share to disconnect 
# so by changing the timer we can specify a smaller timeframe where it will hang and wait.
# Mounting through cmd+k in finder specifies a timeframe that is 35 seconds or less but the
# command line mount uses this variable so we are trying to make the values consistent between
# the two.
sub ChangeAFPTimer($)
{
    my $afp_timer = $_[0];
    (defined $MACVER) or $MACVER = GetMacOSVersionString(3);
    if (CompareVersion($MACVER, '10.5.*') == 0 || CompareVersion($MACVER, '10.6.*') == 0)
    {
        DEBUG_OUT("Changing the AFP reconnect timer...");
        my $ShareClientPlist = CentrifyDC::GP::Plist->new(
            '/Library/Preferences/com.apple.AppleShareClient.plist');
        if (! $ShareClientPlist)
        {
            ERROR_OUT("Cannot create plist instance. plist: [com.apple.AppleShareClient.plist]");
            return undef;
        }
        if (! $ShareClientPlist->load())
        {
            ERROR_OUT("Cannot load plist [com.apple.AppleShareClient.plist]");
            return undef;
        }
        my $rc = $ShareClientPlist->set(undef, 'afp_reconnect_max_time', ToCF($afp_timer, CF_INTEGER));
        if (! $rc)
        {
            ERROR_OUT("Cannot set afp_reconnect_max_time in com.apple.AppleShareClient.plist");
            return undef;
        }
        if (! $ShareClientPlist->save())
        {
            ERROR_OUT("Cannot save plist [com.apple.AppleShareClient.plist]");
            return undef;
        }
    }
}

# This function retrieves the afp_reconnect_max_time variable value under /Library/Preferences.
# This is so that we can copy back the original value after we finish mounting the share.  Also,
# if the afptimer seems to be a lower value than 35 then we can also ignore setting the timer to 
# 35 since that will cause the mount to take even longer than desired to disconnect.
sub GetAFPTimer()
{
    DEBUG_OUT("Getting the AFP reconnect timer...");
    my $ShareClientPlist = CentrifyDC::GP::Plist->new(
        '/Library/Preferences/com.apple.AppleShareClient.plist');
    if (! $ShareClientPlist)
    {
        ERROR_OUT("Cannot create plist instance. plist: [com.apple.AppleShareClient.plist]");
        return undef;
    }
    if (! $ShareClientPlist->load())
    {
        ERROR_OUT("Cannot load plist [com.apple.AppleShareClient.plist]");
        return undef;
    }
    my $afp_CFvar = $ShareClientPlist->get(['afp_reconnect_max_time']);
    if (! $afp_CFvar)
    {
        ERROR_OUT("Cannot get afp_reconnect_max_time in com.apple.AppleShareClient.plist");
        return undef;
    }
    my $afp_var = ToString($afp_CFvar);
    return $afp_var;
}

# >>> MAIN >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

my $user = shift;
my $mount_windowshome = shift;
my $create_dock_icon = shift;
my $create_alias = shift;
my $shares = [];
while (my $share = shift)
{
    push(@$shares, GetRealSharePath($share));
}

if (! defined($user))
{
    ERROR_OUT('User not specified');
    exit(2);
}

my $cur_user = (getpwuid($>))[0];

if ($user ne $cur_user)
{
    DEBUG_OUT("loginmount is for user [%s]. skip current user [%s]", $user, $cur_user);
    exit(0);
}

GetPaths($user) or FATAL_OUT("Cannot get required file/folder paths");

my $ret = 0;

$ret = Map($user, $mount_windowshome, $create_dock_icon, $create_alias, $shares);

$ret or FATAL_OUT();

