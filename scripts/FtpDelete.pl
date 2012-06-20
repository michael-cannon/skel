#!/usr/bin/perl

# Example
# ./FtpDelete.pl -d ${DAYS} ftp://mcannon@backup9.gnax.net/TCcannon01 <password-backup

use warnings;

use Net::FTP;
use Getopt::Long;
use Time::ParseDate;

sub printError
{
  my ($theErrorText) = @_;
  print "Error: $theErrorText!\n";
}

sub printErrorAndExit
{
  my ($theErrorText) = @_;
  printError($theErrorText);
  exit(-1);
}

sub printUsageAndExit
{
  print <<HERE;
Usage:
  perl FtpDelete.pl <options> ftp://<user>@<host>/<dir>
Options may be:
  --passive|-p 
    Do passive FTP transfers.
  --days=<number>|-d <number> 
    Remove files older than <number> days (3 days is the default).
  --verbose|-v
    Print verbose progress messages.
HERE
  exit(-2);
}

my ($doPassive, $beVerbose) = (0, 0);
my $days = 3;
GetOptions(
    'passive|p' => \$doPassive, 'verbose|v' => \$beVerbose,
    'days|d=f' => \$days)
  or printUsageAndExit();

if (1 != @ARGV) {
  printUsageAndExit();
}

my $url = $ARGV[0];
if ($url !~ m!ftp://([^@]+)@([^/]+)(/.*)!i) {
  print "Incorrect argument, should be 'ftp://<user>@<host>/<dir>'\n";
  exit(-2);
}

my ($host, $user, $dir) = ($2, $1, $3);

print "Password: ";
STDOUT->flush();
my $password = <STDIN>;
chomp $password;
print "\n";

print "Connecting to '$host'...\n";
my $ftp = Net::FTP->new($host, Passive=>$doPassive)
  or printErrorAndExit("Failed to connect");

print "Connected, logging in as '$user'...\n";
$ftp->login($user,$password)
  or printErrorAndExit("Failed to login");

print "Changing directory to '$dir'...\n";
$ftp->cwd($dir)
  or printErrorAndExit("Failed to change directory");

{
  my $listingRef = $ftp->dir()
    or printErrorAndExit('Failed to get directory contents');
  print "\nDirectory listing:\n";
  foreach my $line (@$listingRef) {
    print "  $line\n";
  }
  print "\n";
}

print "Deleting.\n";

my $options =
  {
    days => $days,
    verbose => $beVerbose,
  };
my $results =
  {
    filesDeleted => 0,
    dirsDeleted => 0,
    totalFilesDeleted => 0,
    totalDirsDeleted => 0,
    dirIsEmpty => 0,
  };
deleteFilesAndDirs($ftp, '', '', $options, $results);

print "Done.\n";
print 
    "$results->{filesDeleted} top-level files deleted "
    . "($results->{totalFilesDeleted} total).\n";
print
    "$results->{dirsDeleted} top-level directories deleted "
    . "($results->{totalDirsDeleted} total).\n";

{
  # The work-around of a strange bug when the *old* directory contents
  # was displayed.
  sleep(2);

  my $listingRef = $ftp->dir()
    or printErrorAndExit('Failed to get directory contents');
  print "\nDirectory listing:\n";
  foreach my $line (@$listingRef) {
    print "  $line\n";
  }
  print "\n";
}

exit(0);

sub deleteFilesAndDirs
{
  my (
      $theFtp, $theDirPrefix, $theMsgPrefix, 
      $theOptionsRef, $theResultsRef
      ) = @_;

  my $secondsInDay = 60*60*24;
  my $verbose = $theOptionsRef->{verbose};

  my $dirListRef = $theFtp->dir($theDirPrefix);
  if (! $dirListRef) {
    printError($theMsgPrefix.'Failed to get the directory contents');
    return 0;
  }

  LISTING_LINE: foreach my $line (@$dirListRef) {
    $line =~ m/^([^ ]+) +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +([^ ]+ +[^ ]+ +[^ ]+) +([^ ]+)/
      or next LISTING_LINE;
    my ($name, $timeText, $attrs) = ($3, $2, $1);

    $name =~ m/^\.{1,2}$/ and next LISTING_LINE;

    my $fullName = "$theDirPrefix$name";
    my $isDir = ($attrs =~ m/d/i);
    my $dirIsntEmpty = 0;

    $verbose and print 
        $theMsgPrefix
        . ($isDir ? "Directory '$name'.\n" : "File '$name'.\n");

    if ($isDir) {
      $verbose and print $theMsgPrefix."Entering '$fullName'.\n";

      my $results =
        {
          filesDeleted => 0,
          dirsDeleted => 0,
          totalFilesDeleted => 0,
          totalDirsDeleted => 0,
          dirIsntEmpty => 0,
        };
      my $dirSucceeded = deleteFilesAndDirs(
          $theFtp, "$fullName/", "$theMsgPrefix  ",
          $theOptionsRef, $results);
      $dirIsntEmpty = $results->{dirIsntEmpty};
      $theResultsRef->{totalFilesDeleted} += $results->{totalFilesDeleted};
      $theResultsRef->{totalDirsDeleted} += $results->{totalDirsDeleted};

      $verbose and print $theMsgPrefix."Leaving '$fullName'.\n";

      if (! $dirSucceeded) {
        $verbose and print 
            $theMsgPrefix
            . "'$name' wasn't processed successfully, skipping.\n";
        $theResultsRef->{dirIsntEmpty} = 1;
        next LISTING_LINE;
      }
    }

    my $time = parsedate($timeText);
    my $currTime = time();

    my $isOld = ($currTime - $time > $secondsInDay * $theOptionsRef->{days});
    my $deleted = 0;
    if ($isOld) {
      if ($dirIsntEmpty) {
        $verbose and print 
            $theMsgPrefix."'$name' is old, but it's a non-empty directory.\n";
      } else {
        $verbose and print $theMsgPrefix."'$name' is old, deleting...\n";
        $deleted = ($isDir 
          ? $theFtp->rmdir($fullName) 
          : $theFtp->delete($fullName));

        $deleted or printError($theMsgPrefix."Failed to delete '$name'");
        $deleted and ($isDir
          ? (
              ++$theResultsRef->{dirsDeleted},
              ++$theResultsRef->{totalDirsDeleted})
          : (++$theResultsRef->{filesDeleted},
              ++$theResultsRef->{totalFilesDeleted}));
      }
    }

    $deleted or $theResultsRef->{dirIsntEmpty} = 1;
  }

  return 1;
}
