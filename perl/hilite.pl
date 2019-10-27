#!/bin/perl -s -wn
#use strict;
use warnings;
use Term::ANSIColor;

use constant {
    SOH                      => '\x01',
    RESET                    => color("reset"),
    TRACE                    => '^.{0,60}\bTRACE\b',
    BOLD_BLUE                => color("bold blue"),
    DEBUG                    => '^.{0,60}\bDEBUG\b|#%%',
    GREEN                    => color("green"),
    MAGENTA                  => color("magenta"),
    INFO                     => '^.{0,60}\bINFO\b|#--',
    BOLD_WHITE               => color("bold white"),
    WARN                     => '^.{0,60}\bWARN\b|#>>',
    BOLD_YELLOW              => color("bold yellow"),
    ERROR                    => '^.{0,60}\bERROR\b|#!!',
    EXCEPTION                => '^\S*Exception|^\s+at ',
    BOLD_RED                 => color("bold red"),
    FATAL                    => '^.{0,60}\bFATAL\b',
    BLINK_BOLD_YELLOW_ON_RED => color("blink bold yellow on_red"),
    RED_HILITE_COLOR         => color("bold white on_red"),
    GREEN_HILITE_COLOR       => color("black on_green"),
    BLUE_HILITE_COLOR        => color("bold white on_blue"),
    MAGENTA_HILITE_COLOR     => color("bold white on_magenta"),
    YELLOW_HILITE_COLOR      => color("black on_yellow"),
    WHITE_HILITE_COLOR       => color("black on_white"),
};

BEGIN {
    if ($help) {
        print "Usage:\n";
        print "  hilite.pl [-options] [-trace|debug|info|warn|error|fatal] [-red=<RE>] [file]\n";
        print "\nOptions:\n";
        print "  -m=<re>     match expression with log level and above\n";
        print "  -a=<re>     match expression with any log level\n";
        print "  -aa=<re>    same as '-a', useful for aliasing\n";
        print "  -e=<re>     exit expression\n";
        print "  -t=<re>     trigger expression\n";
        print "  -r=<re>     trigger reset expression\n";
        print "  -c=<re>     cut expression\n";
        print "  -bamboo     strip prefix added by bamboo before matching\n";
        print "  -v=<re>     exclude lines that match expression\n";
        print "  -vv=<re>    same as '-v', useful for aliasing\n";
        print "  -i          case-insensitive expression matching\n";
        print "  -n          prefix output with line number\n";
        print "  -fix        match FIX messages with any log level\n";
        print "  -splunk     replace Splunk's FIX delimiter ' | ' with '^'\n";
        print "  -csv=<re>   extract comma separated values from (tag=value) pairs for matching tags\n";
        print "  -debug|...  include only entries with specified priority and above\n";
        print "  -red=<re>   highlight matching text in red/green/blue/magenta/yellow/white\n";
        print "  -x          disable all highlighting\n";
        print "  -help       show this help\n";
        print "\nPriorities:\n";
        print "  debug : #%%\n";
        print "  info  : #--\n";
        print "  warn  : #>>\n";
        print "  error : #!!\n";
        print "\nHighlights:\n";
        print "  magenta : ~&&\n";
        print "  blue    : ~##\n";
        print "  green   : ~%%\n";
        print "  white   : ~--\n";
        print "  yellow  : ~>>\n";
        print "  red     : ~!!\n";
        print "\nExample:\n";
        print "  hilite.pl -m=8=FIX -warn -blue=Protocol myapp.log\n";
        print "  hilite.pl -fix -csv=\"11|37\" myapp.log\n";
        exit;
    }

    our ($m, $a, $aa, $e, $exit, $t, $triggered, $r, $c, $bamboo, $i, $v, $n, $x, $fix, $splunk, $help);
    our ($trace, $debug, $info, $warn, $error, $fatal);
    our ($red, $green, $blue, $magenta, $yellow, $white);
    our ($isNewEntry, $matchedEntry);
    our (%exact, %fix, %hilite);

    $isNewEntry = 0;
    $matchedEntry = (!$trace and !$debug and !$info and !$warn and !$error and !$fatal);

    # case-insensitive
    if ($i) {
        $m and $m = '(?i)' . $m;
        $a and $a = '(?i)' . $a;
        $aa and $aa = '(?i)' . $aa;
        $e and $e = '(?i)' . $e;
        $t and $t = '(?i)' . $t;
        $r and $r = '(?i)' . $r;
        $c and $c = '(?i)' . $c;
        $v and $v = '(?i)' . $v;
        $vv and $vv = '(?i)' . $vv;
        $red and $red = '(?i)' . $red;
        $green and $green = '(?i)' . $green;
        $blue and $blue = '(?i)' . $blue;
        $magenta and $magenta = '(?i)' . $magenta;
        $yellow and $yellow = '(?i)' . $yellow;
        $white and $white = '(?i)' . $white;
    }

    if (!$x) {
        # log levels
        $exact{"${\TRACE}"} = BOLD_BLUE;
        $exact{"${\DEBUG}"} = GREEN;
        $exact{"${\INFO}"} = BOLD_WHITE;
        $exact{"${\WARN}"} = BOLD_YELLOW;
        $exact{"${\ERROR}"} = BOLD_RED;
        $exact{"${\EXCEPTION}"} = BOLD_RED;
        $exact{"${\FATAL}"} = BLINK_BOLD_YELLOW_ON_RED;
        # log message highlights
        $exact{"~&&.*"} = MAGENTA_HILITE_COLOR;
        $exact{"~##.*"} = BLUE_HILITE_COLOR;
        $exact{"~%%.*"} = GREEN_HILITE_COLOR;
        $exact{"~--.*"} = WHITE_HILITE_COLOR;
        $exact{"~>>.*"} = YELLOW_HILITE_COLOR;
        $exact{"~!!.*"} = RED_HILITE_COLOR;
        # FIX
        $exact{"35=[ADVH]"} = GREEN_HILITE_COLOR;
        $exact{"35=[0]"} = BLUE_HILITE_COLOR;
        $exact{"35=[1245hFG]"} = YELLOW_HILITE_COLOR;
        $exact{"35=[3j9]"} = RED_HILITE_COLOR;
        $exact{"35=[8W]"} = WHITE_HILITE_COLOR;
        $fix{"43|97"} = BOLD_RED;
        $fix{"54|55|38|44|40|59|126|432"} = GREEN;
        $fix{"34|11|41|37|17"} = BOLD_BLUE;
        $fix{"39|150|151|58|32|31|6|14"} = BOLD_YELLOW;
        $fix{"100|207|30|15|48|448|2595|528"} = MAGENTA;
        # specified highlights
        if ($red) {
            $hilite{$red} = RED_HILITE_COLOR;
        }
        if ($green) {
            $hilite{$green} = GREEN_HILITE_COLOR;
        }
        if ($blue) {
            $hilite{$blue} = BLUE_HILITE_COLOR;
        }
        if ($magenta) {
            $hilite{$magenta} = MAGENTA_HILITE_COLOR;
        }
        if ($yellow) {
            $hilite{$yellow} = YELLOW_HILITE_COLOR;
        }
        if ($white) {
            $hilite{$white} = WHITE_HILITE_COLOR;
        }
    }
}

# strip highlighting
s/\e\[\d*(?>(;\d+)*)m//g;

# trigger
if ($t) {
    if ($triggered) {
        if ($r) {
            $triggered = !m/$r/;
        }
    } else {
        $triggered = m/$t/;
        $triggered or next;
    }
}

# exit
$exit = ($e and m/$e/);

# strip bamboo prefix
!$bamboo or s/^[^\t]*?\t[^\t]*?\t//;

if (!$exit and (!$fix or !m/8=FIX/)) {
    # match new entries against log level
    $isNewEntry = m/${\TRACE}|${\DEBUG}|${\INFO}|${\WARN}|${\ERROR}|${\FATAL}/;
    if ($isNewEntry) {
        $matchedEntry = ($a and m/$a/ or $aa and m/$aa/);
        if (!$matchedEntry) {
            !$v or m/$v/ and next;
            !$vv or m/$vv/ and next;
            !$trace
                or !($matchedEntry = m/${\TRACE}|${\DEBUG}|${\INFO}|${\WARN}|${\ERROR}|${\FATAL}/)
                and next;
            !$debug or !($matchedEntry = m/${\DEBUG}|${\INFO}|${\WARN}|${\ERROR}|${\FATAL}/) and next;
            !$info or !($matchedEntry = m/${\INFO}|${\WARN}|${\ERROR}|${\FATAL}/) and next;
            !$warn or !($matchedEntry = m/${\WARN}|${\ERROR}|${\FATAL}/) and next;
            !$error or !($matchedEntry = m/${\ERROR}|${\FATAL}/) and next;
            !$fatal or !($matchedEntry = m/${\FATAL}/) and next;
            $matchedEntry = (!$m or m/$m/); # apply the filter
        }
    }
    $matchedEntry or next;
}

# cut
!$c or s/$c//gi;

# SOH
s/${\SOH}/\^/gi;

# Splunk
!$splunk or s/ \| /\^/gi;

# FIX to CSV
if ($csv and m/8=FIX/) {
    while (s/\^($csv)=([^\^]*)//) {
        print "${2},";
    }
    print "\n" and next;
}

if (!$x) {
    # exact matches
    my ($key);
    foreach $key (keys %exact) {
        s/($key)/$exact{$key}${1}${\RESET}/g;
    }

    # FIX
    foreach $key (keys %fix) {
        s/\^(($key)=[^\^]*)/\^$fix{$key}${1}${\RESET}/g;
    }
    
    # highlighting
    foreach $key (keys %hilite) {
        s/($key)/$hilite{$key}${1}${\RESET}/g;
    }
}

# line number
$n and printf "%05d: ", $.;

print and $exit and exit 0;