#!/bin/sh
#######################################################################
#   Script: exgfsmos_extprep.sh.ecf
#
#  Purpose: This script extracts multiple fields from NCEP GFS pgrb2
#           (GRIB2) files. The fields are interpolated from 1.0 deg.
#           lat/lon grid to 95km. This script uses NCEP utilities
#           wgrib2, copygb2, and grb2index and works on forecast
#           projections 99 through 192 at 95km and 204 through
#           384 at 190.5km.
#
#  History: Jun 2012 - EFE - Removed copygb2 line that extracts
#                            0-1000m Storm Relative Helicity. This
#                            field was removed from pgrb2 files with
#                            the 5/22/2012 GFS Hybrid EnKF Implementation.
#           Jul 2013 - EFE - Moved into vertical structure.
#           Jul 2013 - EFE - Reworked the script to use wgrib2 instead
#                            copygb2 for interpolation.
#           Mar 2014 - EFE - wgrib2 used to inventory and parse global
#                            GRIB2 file. copygb2 now being used to perform
#                            regridding to MDL archive grid.
#           Apr 2014 - EFE - Set GDS from one file by parsing for a specific
#                            GDS line.
#           Dec 7 2018        - change $COMINgfs to the new path that
#                               GFS-FV3v15 used as output
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'

export DAT="$PDY$cyc"

cd $DATA/prep
cpreq $DATA/ncepdate .

########################################
set -x
msg="Begin job for $job"
postmsg "$jlogfile" "$msg"
########################################

echo MDLLOG: `date` - Begin job exgfsmos_extprep
echo $PDY $cyc: Date and Cycle - echo PDY and cyc

#######################################################################
# LOOP THROUGH PROJECTIONS
#######################################################################
for tau in $(seq -f %03g 99 3 192 && seq -f %03g 204 12 384)
do

#######################################################################
# SET THE GRID SPECS FOR WGRIB2 AND COPY PGRIB2 FILE
#######################################################################
  if [ $tau -le 192 ]; then
     # 95KM NPS
     GDS="$(grep '^GFS95:' $FIXcode/mdl_copygb2_gds | cut -d":" -f2)"
     cp $COMINgfs/${cyc}/${COMPONENT}/gfs.${cycle}.pgrb2.1p00.f${tau} gfs.$PDY$cyc.pgrb2f$tau
  elif [ $tau -ge 204 ]; then
     # 190KM NPS
     GDS="$(grep '^GFS190:' $FIXcode/mdl_copygb2_gds | cut -d":" -f2)"
     cp $COMINgfs/${cyc}/${COMPONENT}/gfs.${cycle}.pgrb2.2p50.f${tau} gfs.$PDY$cyc.pgrb2f$tau
  fi

  g2=gfs.$PDY$cyc.pgrb2f$tau

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE, THEN COOPYGB2 FOR
# REGRIDDING TO MDL ARCHVIE GRID.
# (NON-PRECIP FIELDS) -- INTERPOLATION IS BILINEAR
#######################################################################
   $WGRIB2 $g2 > grib2.inv

   grep -f $FIXgfs_mos/mdl_gfs_nonpcp.wgrib2 grib2.inv | \
   $WGRIB2 -i $g2 -grib nonpcp.f$tau.pgrb2

   $COPYGB2 -a -g"$GDS" -i0 -x nonpcp.f$tau.pgrb2 mdl.gfsx.$cycle.pgrb2

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE, THEN COOPYGB2 FOR
# REGRIDDING TO MDL ARCHVIE GRID.
# (PRECIP FIELDS) -- INTERPOLATION IS BUDGET
#######################################################################

   $WGRIB2 $g2 > grib2.inv

   grep -f $FIXgfs_mos/mdl_gfs_pcp.wgrib2 grib2.inv | \
   $WGRIB2 -i $g2 -grib pcp.f$tau.pgrb2

   $COPYGB2 -a -g"$GDS" -i3 -x pcp.f$tau.pgrb2 mdl.gfsx.$cycle.pgrb2


done  # for tau

$GRB2INDEX mdl.gfsx.$cycle.pgrb2 mdl.gfsx.$cycle.pgrb2.index

#######################################################################
# GRB2TOMDLP
# CONVERT GRIB2 TO TDLPACK FOR HOURS 0 TO 96
#######################################################################

export pgm=mdl_grb2tomdlp
. prep_step
export FORT10="ncepdate"
export FORT20="mdl.gfsx.$cycle.pgrb2"
export FORT21="mdl.gfsx.$cycle.pgrb2.index"
export FORT28="$FIXgfs_mos/mdl_gfsxprep_grb2tomdlp.lst"
export FORT29="$FIXcode/mdl_gridlst"
export FORT30="$FIXcode/mdl_mos2000id.tbl"
export FORT60="pkgfsxraw.$DAT"
echo MDLLOG:  `date` - Program mdl_grb2tomdlp has begun
startmsg
$EXECcode/mdl_grb2tomdlp < $PARMgfs_mos/mdl_gfsgrb2tomdlp.cn >> $pgmout 2>errfile
export err=$?; err_chk

echo MDLLOG:  `date` - Program mdl_grb2tomdlp has ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs pkgfsxraw.$DAT $COMOUT/mdl_gfsxpkd.$cycle
  cpfs mdl.gfsx.$cycle.pgrb2 $COMOUT
  cpfs mdl.gfsx.$cycle.pgrb2.index $COMOUT
fi

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"
echo MDLLOG: `date` - Job exgfsmos_extprep has ended.

#######################################################################
