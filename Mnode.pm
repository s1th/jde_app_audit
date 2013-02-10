package Mnode;
use strict;

#==========
#Constructor
#==========
sub spawn
{
 my $proto = shift;
 my $class = ref($proto) || $proto;
 my $self  = {};
 my($menu,$sel,$jexc,$jver,$mexc,$pvert,$adv,$set,$batv) = @_;
 $self->{MENU}  = $menu;
 $self->{SEL}   = $sel;
 $self->{JEXC}  = $jexc;
 $self->{JVER}  = $jver;
 $self->{MEXC}  = $mexc;
 $self->{PVERT} = $pvert;
 $self->{ADV}   = $adv;
 $self->{SET}   = $set;
 $self->{BATV}  = $batv;
 bless($self,$class);
 return $self;
}
#=====
#Print
#=====
sub tostring
{
 my $self = shift;
 print "menu  =\t $self->{MENU}","\n";
 print "sel   =\t $self->{SEL}","\n";
 print "jexc  =\t $self->{JEXC}","\n";
 print "jver  =\t $self->{JVER}","\n";
 print "mexc  =\t $self->{MEXC}","\n",;
 print "pvert =\t $self->{PVERT}","\n";
 print "adv   =\t $self->{ADV}","\n";
 print "set   =\t $self->{SET}","\n";
 print "batv  =\t $self->{BATV}","\n";
}

#========
#Get menu
#========
sub get_menu
{
 my $self = shift;
 return $self->{MENU};
}

#============
#Get Selection
#============
sub get_sel
{
 my $self = shift;
 return $self->{SEL};
}

#================
#Get Job to Execute
#================
sub get_jexc
{
 my $self = shift;
 return $self->{JEXC};
}

#==============
#Get Job Version
#==============
sub get_jver
{
 my $self = shift;
 return $self->{JVER};
}

#==================
#Get Menu to Execute
#==================
sub get_mexc
{
 my $self = shift;
 return $self->{MEXC};
}

#===============
#Get Parent Vertex
#===============
sub get_parent_vertex
{
 my $self = shift;
 return $self->{PVERT};
}

#==========================
#Get Advanced/Tech Ops Menu
#==========================
sub get_adv
{
 my $self = shift;
 return $self->{ADV};
}

#==============
#Get Setup Menu
#==============
sub get_set
{
 my $self = shift;
 return $self->{SET};
}

#==============
#Get Batch Value
#==============
sub get_batv
{
 my $self = shift;
 return $self->{BATV};
}

#=======
#Return 1
#=======
1;



