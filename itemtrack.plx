#!/usr/bin/perl
# itemtrack.plx
use warnings;
use strict;

#Useful constants
#Item name string
my $ITEMNAME = "Item Name: ";
#Item tags
my $TAG = "Tags: ";
#Description of the item's location
my $DESC = "Description: ";

#SUBROUTINE PROTOTYPES

my @names;
my %nametag;
my %namedesc;
my %tagname;

my $file;

#Indicates if the contents of the text file has been changed
my $changedflag = 0;

#my $newname;

#while (@ARGV) {
#  my $option = shift;
#  if ($option =~ /--add/) {
#    $newname = shift;
#    add($newname);
#  }
#  elsif ($option =~ /--tags/) {
#    my $tags = shift;
#    setTags($tags, $newname);
#  }
#  else {
#    $file = $option;
    $file = shift;
    open my $DB, "$file" or die "Unable to open $file";
    readin($DB);
    close $DB;
    #We should add some code to deal with what happens when there is no
    #filename given for my $file = shift to work.
#  }
#}


my $contflag = 1;

do {
  print <<EOF;
(0) Exit
(1) Search for item
(2) Edit item
(3) Print all items, tags, and descriptions
EOF
  print "> ";
  my $choice = <STDIN>;
  print "\n";
  if ($choice == 0) {
    $contflag = 0;
  } elsif ($choice == 1) {
    lookup();
  } elsif ($choice == 2) {
    edit();
  } elsif ($choice == 3) {
    print_all();
  } else {
    print "Invalid input. Use only 0, 1, 2, or 3!\n"
  }
} while($contflag);

if ($changedflag) {
  print "Addition/removal of entries has occurred. Write changes (y/n)? ";
  my $stdin = <STDIN>;
  chomp $stdin;
  writeout() if ($stdin eq "y");
}

#SUBROUTINES
sub readin {
  my $fh = shift;
  my $name;
  my $linenum;

  while (<$fh>) {
    #Blank lines are separators between items. Also skip comments
    next if ($_ eq "\n") || (/^#/);

    if (/^$ITEMNAME/) { #name line
      $names[$#names + 1] = substr($_, length($ITEMNAME));
      chomp $names[$#names];
      $name = $names[$#names];
    }
    elsif (/^$TAG/ && defined $name) { #tag line
      $nametag{$name} = substr($_, length($TAG));
      chomp $nametag{$name};
      #This is an excellent spot to form the hash for tags -> item name.
      additem2tag($nametag{$name}, $name);
    }
    elsif (/^$DESC/ && defined $name) { #description of location line
      $namedesc{$name} = substr($_, length($DESC));
      chomp $namedesc{$name};
    }
    else { #Now you have something really weird in this file
      print "Something weird going on at $linenum in $file.\n";
    }
  }
}

sub print_all {
  for (@names) {
    print "Item Name: $_\n";
    print "Tags: $nametag{$_}\n" if (exists $nametag{$_});
    print "Description: $namedesc{$_}\n" if (exists $namedesc{$_});
    print "\n";
  }
}

#additem2tag(<list of tags>, <name of item described by tags>)
sub additem2tag {
  my ($taglist, $name) = @_;
  #split up the list of tags into individual tokens
  #Add each of the tags as keys to the %tagname hash, with the name as the value
  for my $tag ($taglist =~ /\w+/g)
  {
    unless (exists $tagname{$tag}) {
      #The [] brackets form a _reference_ to an array.
      $tagname{$tag} = [ $name ];
    }
    else { #tag already exists in the hash
      #The following line does not work because the reference array is COPIED
      #@namear = @{$tagname{$tag}};
      #We can make it a bit simpler to read, however, by doing this,
      #which adds $name to the referenced array
      my $ref = $tagname{$tag};
      ${$ref}[$#{$ref} + 1] = $name;
    }
  }
}

sub lookup {
  print "\n";
  
  my $contflag = 1;

  do {
    print <<EOF;
(0) Back
(1) Search by name
(2) Search by tags
EOF

    print "> ";
    my $choice = <STDIN>;
    print "\n";
    if ($choice == 0) {
      $contflag = 0;
    }
    elsif ($choice == 1) { #Search by name
      searchbyname();
    }
    elsif ($choice == 2) { #Search using tags
      searchbytags();
    }
    else {
      print "Input only 0, 1, or 2!\n";
    }
  } while ($contflag);
}

sub edit {
  my $contflag = 1;
  do {
    print <<EOF;
(0) Back
(1) Add
(2) Remove
EOF
    print "> ";
    my $choice = <STDIN>;
    print "\n";
    chomp $choice;
    if ($choice == 0) {
      $contflag = 0;
    }
    elsif ($choice == 1) { #Add item
      print "Name of item to add: ";
      my $newname = <STDIN>;
      chomp $newname;
      print "Tags of the item (separate by space): ";
      my $newtags = <STDIN>;
      chomp $newtags;
      print "Description of item's location: ";
      my $newdesc = <STDIN>;
      chomp $newdesc;
      print "\n";
      additem($newname, $newtags, $newdesc);
      $changedflag = 1;
    }
    elsif ($choice == 2) { #Remove item
      print "Name of item to remove: ";
      my $choice = <STDIN>;
      chomp $choice;
      removeitem($choice);
      $changedflag = 1;
    }
  } while ($contflag)
}

sub printitem {
  my @matches = @_;
  for my $i (0 .. $#matches) {#then search key exists!
    my $name = $matches[$i];
    print "Item Name: $name\n";
    print "Tags: $nametag{$name}\n" if exists $nametag{$name};
    print "Description: $namedesc{$name}\n" if exists $nametag{$name};
    print "\n";
  }
}

sub searchbyname {
  print "Item name> ";
  my $choice = <STDIN>;
  print "\n";
  chomp $choice;
  my @matches = grep /$choice/i, @names;
  printitem(@matches);
}

sub searchbytags {
  print "Tags to search for> ";
  my $choice = <STDIN>;
  print "\n";
  chomp $choice;
  #1) Get all the items from the first tag's hash (@items)
  #2) Search through each of the items in @items. The tags of each of the items
  #   should contain all the remaining tags
  #3) Eliminate the ones that don't have all of the remaining tags

  my @tags = ($choice =~ /\w+/g);
  my $i = 1;
  my @intersection; #This will be the results array;
  for (@tags) {
    if (exists $tagname{$_}) {
      @intersection = @{$tagname{$_}};
      last;
    }
  }
  while($i < scalar(@tags) && @intersection) { #There are array elements
    my $tag = $tags[$i];
    #let's form the intersection of the arrays referenced by the tags
    if (exists $tagname{$tag}) {
      my @namesoftag = @{$tagname{$tag}};
      #print "\nFor $tag: @namesoftag\n";
      #print "\n@intersection\n";

      my %count;
      for my $thename (@intersection, @namesoftag) {
	$count{$thename}++;
      }

      my @newintersection;
      for my $thename (keys %count) {
	if ($count{$thename} > 1) {
	  push @newintersection, $thename;
	}
      }
      @intersection = @newintersection;
    }
    $i++;
  }
  printitem(@intersection);
}

#3 parameters: name, tags, description
sub additem {
  my $name = shift;
  my $tags = shift;
  my $desc = shift;
  #check for matches or existing items:
  my @matches = grep /^$name$/, @names;
  #Replace spaces in tags with commas
  $tags =~ s/[^\w\d]+/,/g;
  print "@matches\n";
  if (@matches) {
    removeFromTags($nametag{$matches[0]}, $name);
    $nametag{$matches[0]} = $tags;
    additem2tag($tags, $name);
    $namedesc{$name} = $desc;
  }
  else { #We can just add it in! We're all clear!
    push @names, $name;
    $nametag{$name} = $tags;
    additem2tag($tags, $name);
    $namedesc{$name} = $desc;
  }
}

sub removeFromTags {
  my $tags = shift;
  my $thename = shift;
  for my $tag ($tags =~ /\w+/g) {
    my $index = indexof($tagname{$tag}, $thename);
    unless ($index == -1) {
      splice (@{$tagname{$tag}}, $index, 1);
    }
  }
}

sub removeitem {
  my $thename = shift;
  my $index = indexof(\@names, $thename);
  unless ($index == -1) {
    splice(@names, $index, 1);
    removeFromTags($nametag{$thename}, $thename);
    delete $nametag{$thename};
    delete $namedesc{$thename};
  }
}

sub indexof {
  my $arref = shift;
  my $element = shift;
  my $index = 0;
  $index++ until $index > $#{$arref} or ${$arref}[$index] eq $element;
  return ($index > $#{$arref} ? -1 : $index);
}

sub writeout {
  #$ITEMNAME<name>
  #$TAG<tags>
  #$DESC<description>

  my ($choice, $writable) = (0, 0);

  print "File to write to: ";
  my $fileout = <STDIN>;
  chomp $fileout;

  #Check for existence
  if (-e $fileout) {
    print "Are you sure you want to overwrite this file? (y/n) ";
    $choice = <STDIN>;
    chomp $choice;
    if ($choice eq "y") {
      #Check for writability
      if (-w $fileout) {
        $writable = 1;
      }
    }
  }
  else { #File doesn't exist. Write anyways
    $writable = 1;
  }
  open FOUT, "> $fileout" or die "Unable to open file for writing: $!";

  for my $entry (@names) {
    print FOUT $ITEMNAME, $entry, "\n";
    print FOUT $TAG, $nametag{$entry}, "\n";
    print FOUT $DESC, $namedesc{$entry}, "\n\n";
  }

  close FOUT;
}
