#!/bin/sh
#######################################################################
#   Script: exgfsmos_extprep47.sh.ecf
#
#  Purpose: This script extracts multiple fields from NCEP GFS pgrb2
#           (GRIB2) files. The fields are interpolated from 0.5 deg.
#           lat/lon grid to MDL GFS (2010 expanded) 47km. This script
#           uses NCEP utilities wgrib2 and grb2index and works on
#           forecast projections 99 through 192 at 47km and 204 through
#           384 at 95km.
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
#           Aug 2014 - SDS - Modified for loop to include additional 
#                            3-hourly projections and to change the 1
#                            degree cut-off to tau 252.
#           Oct 2014 - SDS - Changed names of model GRIB2 files.
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

echo MDLLOG: `date` - Begin job exgfsmos_extprep47
echo $PDY $cyc: Date and Cycle - echo PDY and cyc

#######################################################################
# LOOP THROUGH PROJECTIONS
#######################################################################
for tau in $(seq -f %03g 99 3 240 && seq -f %03g 252 12 384)
do
#######################################################################
# SET THE GRID SPECS FOR WGRIB2 AND COPY PGRIB2 FILE
#######################################################################
  if [ $tau -le 240 ]; then
     # 47KM NPS
     GRID="$(grep '^GFS47:' $FIXgfs_mos/mdl_wgrib2_gds | cut -d":" -f2-)"
     cp $COMINgfs/${cyc}/atmos/gfs.${cycle}.pgrb2.0p25.f${tau} gfs.$PDY$cyc.pgrb2f$tau
     if [ $? -ne 0 ]; then
        msg="WARNING: 1/4-DEG PGRB2 GFS FILE NOT FOUND FOR ${tau}"
        postmsg "$jlogfile" "$msg"
     fi
  elif [ $tau -ge 252 ]; then
     # 95KM NPS
     GRID="$(grep '^GFS95:' $FIXgfs_mos/mdl_wgrib2_gds | cut -d":" -f2-)"
     cp $COMINgfs/${cyc}/atmos/gfs.${cycle}.pgrb2.0p50.f${tau} gfs.$PDY$cyc.pgrb2f$tau
     if [ $? -ne 0 ]; then
        msg="WARNING: 1/2-DEG PGRB2 GFS FILE NOT FOUND FOR ${tau}"
        postmsg "$jlogfile" "$msg"
     fi
  fi

  g2=gfs.$PDY$cyc.pgrb2f$tau

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE AND THEN REGRID TO MDL
# MDL ARCHVIE GRID.
# (NON-PRECIP FIELDS) -- INTERPOLATION IS BILINEAR
#######################################################################
   $WGRIB2 $g2 > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_gfs_nonpcp.wgrib2 grib2.inv |
   $WGRIB2 -i $g2 -new_grid_winds grid -new_grid_interpolation bilinear \
                  -append -new_grid ${GRID} mdl.gfsx47.$cycle.pgrb2
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
                  -append -new_grid ${GRID} mdl.gfsx47.$cycle.pgrb2
   export err=$?; err_chk

done  # for tau

$GRB2INDEX mdl.gfsx47.$cycle.pgrb2 mdl.gfsx47.$cycle.pgrb2.index
export err=$?; err_chk

#######################################################################
# GRB2TOMDLP
# CONVERT GRIB2 TO TDLPACK FOR HOURS 0 TO 96
#######################################################################

export pgm=mdl_grb2tomdlp
. prep_step
export FORT10="ncepdate"
export FORT20="mdl.gfsx47.$cycle.pgrb2"
export FORT21="mdl.gfsx47.$cycle.pgrb2.index"
export FORT28="$FIXgfs_mos/mdl_gfsxprep47_grb2tomdlp.lst"
export FORT29="$FIXcode/mdl_gridlst"
export FORT30="$FIXcode/mdl_mos2000id.tbl"
export FORT60="pkgfsxraw47.$DAT"
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
export FORT24="pkgfsxraw47.$DAT"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgrpost_gfscalc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="pkgfsxraw47_calc.$DAT"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_gfs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cat pkgfsxraw47.$DAT pkgfsxraw47_calc.$DAT > $COMOUT/mdl_gfsxpkd47.$cycle
  cpfs mdl.gfsx47.$cycle.pgrb2 $COMOUT
  cpfs mdl.gfsx47.$cycle.pgrb2.index $COMOUT
  cpfs pkgfsxraw47.$DAT $COMOUT/mdl_gfsxpkd47.raw.$cycle
fi

#####################################################################
# GOOD RUN
set +x
echo "************** $job COMPLETED NORMALLY ON THE IBM WCOSS"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
postmsg "$jlogfile" "$msg"
echo MDLLOG: `date` - Job exgfsmos_extprep47 has ended.

#######################################################################
