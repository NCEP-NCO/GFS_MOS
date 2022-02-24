#!/bin/sh
#######################################################################
#   Script: exgfsmos_prep47.sh.ecf
#
#  Purpose: This script extracts multiple fields from NCEP GFS pgrb2
#           (GRIB2) files. The fields are interpolated from 0.5 deg.
#           lat/lon grid to MDL GFS (2010 expanded) 47km. This script
#           uses NCEP utilities wgrib2 and grb2index and works on
#           forecast projection 0 through 96.
#
#  History: Aug 2010 - EFE - Modified from exgfsmos_prep.sh.sms 
#           Jun 2012 - EFE - Removed copygb2 line that extracts
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
#           Jun 2014 - SDS - Added gridpost step to process calculated
#                            u/v earth oriented winds and wind speed
#                            for model archive file.
#           Oct 2014 - SDS - Modified looping through tau and changed 
#                            names of model GRIB2 data.
#           Feb 2016 - SDS - Configured for MPMD and converted grib2
#                            regridding process to use wgrib2 instead
#                            of copygb2 which ran long on Cray.
#           Dec 7 2018        - change $COMINgfs to the new path that
#                               GFS-FV3v15 used as output
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'

export DAT="$PDY$cyc"

cd $DATA/prep47
cpreq $DATA/ncepdate .

########################################
set -x
msg="Begin job for $job"
postmsg "$jlogfile" "$msg"
########################################

echo MDLLOG: `date` - Begin job exgfsmos_prep47
echo $PDY $cyc: Date and Cycle - echo PDY and cyc

#######################################################################
# LOOP THROUGH PROJECTIONS
#######################################################################
for tau in $(seq -f %03g 0 3 96)
do

#######################################################################
# SET THE GRID SPECS FOR WGRIB2
#######################################################################
  GRID="$(grep '^GFS47:' $FIXgfs_mos/mdl_wgrib2_gds | cut -d":" -f2-)"

#######################################################################
# COPY GRIB2 FILES FROM COM
#######################################################################
   cp $COMINgfs/${cyc}/atmos/gfs.${cycle}.pgrb2.0p25.f${tau} gfs.$PDY$cyc.pgrb2f$tau
   if [ $? -ne 0 ]; then
      msg="WARNING: 1/4-DEG PGRB2 GFS FILE NOT FOUND FOR ${tau}"
      postmsg "$jlogfile" "$msg"
   fi
   cp $COMINgfs/${cyc}/atmos/gfs.${cycle}.pgrb2b.0p25.f${tau} gfs.$PDY$cyc.pgrb2bf$tau
   if [ $? -ne 0 ]; then
      msg="WARNING: 1/4-DEG PGRB2B GFS FILE NOT FOUND FOR ${tau}"
      postmsg "$jlogfile" "$msg"
   fi

   g2="gfs.$PDY$cyc.pgrb2f$tau"
   g2b="gfs.$PDY$cyc.pgrb2bf$tau"

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE AND THEN REGRID TO MDL
# MDL ARCHVIE GRID.
# (NON-PRECIP FIELDS) -- INTERPOLATION IS BILINEAR
#######################################################################
   $WGRIB2 $g2 > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_gfs_nonpcp.wgrib2 grib2.inv | 
   $WGRIB2 -i $g2 -new_grid_winds grid -new_grid_interpolation bilinear \
                  -append -new_grid ${GRID} mdl.gfs47.$cycle.pgrb2
   export err=$?; err_chk

   $WGRIB2 $g2b > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_gfs_nonpcp_b.wgrib2 grib2.inv | 
   $WGRIB2 -i $g2b -new_grid_winds grid -new_grid_interpolation bilinear \
                  -append -new_grid ${GRID} mdl.gfs47.$cycle.pgrb2
   export err=$?; err_chk

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE AND THEN REGRID TO MDL
# MDL ARCHVIE GRID.
# (PRECIP FIELDS) -- INTERPOLATION IS BUDGET
#######################################################################
   $WGRIB2 $g2 > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_gfs_pcp.wgrib2 grib2.inv | 
   $WGRIB2 -i $g2 -new_grid_winds grid -new_grid_interpolation budget \
                  -append -new_grid ${GRID} mdl.gfs47.$cycle.pgrb2
   export err=$?; err_chk

done  # for tau

$GRB2INDEX mdl.gfs47.$cycle.pgrb2 mdl.gfs47.$cycle.pgrb2.index
export err=$?; err_chk


#######################################################################
# GRB2TOMDLP
# CONVERT GRIB2 TO TDLPACK FOR HOURS 0 TO 96
#######################################################################

export pgm=mdl_grb2tomdlp
. prep_step
export FORT10="ncepdate"
export FORT20="mdl.gfs47.$cycle.pgrb2"
export FORT21="mdl.gfs47.$cycle.pgrb2.index"
export FORT28="$FIXgfs_mos/mdl_gfsprep47_grb2tomdlp.lst"
export FORT29="$FIXcode/mdl_gridlst"
export FORT30="$FIXcode/mdl_mos2000id.tbl"
export FORT60="pkgfsraw47.$DAT"
echo MDLLOG:  `date` - Program mdl_grb2tomdlp has begun
startmsg
$EXECcode/mdl_grb2tomdlp < $PARMgfs_mos/mdl_gfsgrb2tomdlp.cn >> $pgmout 2>errfile
export err=$?; err_chk

echo MDLLOG:  `date` - Program mdl_grb2tomdlp has ended

#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE TDLPACK GFS MODEL
#                    DATA.  
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS

export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="pkgfsraw47.$DAT"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_gfscalc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="pkgfsraw47_calc.$DAT"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_gfs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cat pkgfsraw47.$DAT pkgfsraw47_calc.$DAT > $COMOUT/mdl_gfspkd47.$cycle
  cpfs mdl.gfs47.$cycle.pgrb2 $COMOUT
  cpfs mdl.gfs47.$cycle.pgrb2.index $COMOUT
fi

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg  "$msg"
echo MDLLOG: `date` - Job exgfsmos_prep47 has ended.

#######################################################################
