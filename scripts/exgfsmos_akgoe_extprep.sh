#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_akgoe_extprep.sh.ecf
#  Purpose: To run all steps necessary to create the GFS-based extended- 
#           range MOS and model data for Alaska gridded MOS.  
#           This script runs all the steps to create the
#           forecasts.  Subsequent scripts will produce the products.
#           This script runs at 00 and 12Z.   
#  Remarks: 
#  HISTORY: Mar 21, 2008      - New job for GFS Gridded MOS for AK.
#                               At the current time this job is just
#                               a run of mospred to get model data
#                               as input to U155 for the temp fields.
#                               In time we'll add the other forecast
#                               steps when we have the goes ready.
#           Sep 25, 2008      - Added steps to evaluated POP and sky
#                               goes.  Also added ids to u201 to get
#                               dmo winds for wind first guess and lapse.
#                               Also changed the check in the beginning
#                               to look for the goe random access file
#                               from the short-range job.
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 10, 2016 SDS  - Configured for MPMD
#           Feb 2018     GAW  - Split off from exgfsmos_akgoe_extfcst.sh.ecf
#                               to run model prep pieces concurrent with 
#                               other prep steps
#           Dec 7 2018        - change $COMINgfs to the new path that
#                               GFS-FV3v15 used as output
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
echo MDLLOG: `date` - Begin job exgfsmos_akgoe_extfcst
set -x

projGroup=$1

cd $DATA/akgoe_prep.${projGroup}
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
# LOOP THROUGH PROJECTIONS
#######################################################################
if [[ $projGroup -eq 1 ]]; then
   tauList=`seq -f %03g 99 3 120`
elif [[ $projGroup -eq 2 ]]; then
   tauList=`seq -f %03g 123 3 144`
elif [[ $projGroup -eq 3 ]]; then
   tauList=`seq -f %03g 147 3 168`
elif [[ $projGroup -eq 4 ]]; then
   tauList=`seq -f %03g 171 3 192`
elif [[ $projGroup -eq 5 ]]; then
   tauList=`seq -f %03g 195 3 216`
elif [[ $projGroup -eq 6 ]]; then
   tauList=`seq -f %03g 219 3 240`
elif [[ $projGroup -eq 7 ]]; then
   tauList=`seq -f %03g 252 12 276`
else
   echo "Unrecognized Projection Group; exiting"
   exit 1
fi

for tau in $tauList;
do
#######################################################################
# SET THE GRID SPECS FOR WGRIB2 AND COPY PGRIB2 FILE
#######################################################################
  GRID="$(grep '^GMOSAK:' $FIXgfs_mos/mdl_wgrib2_gds | cut -d":" -f2-)"
  cp $COMINgfs/${cyc}/${COMPONENT}/gfs.${cycle}.pgrb2.0p25.f${tau} gfs.$PDY$cyc.pgrb2f$tau
  if [ $? -ne 0 ]; then
     msg="WARNING: 1/4-DEG PGRB2 GFS FILE NOT FOUND FOR ${tau}"
     postmsg "$jlogfile" "$msg"
  fi

  g2=gfs.$PDY$cyc.pgrb2f$tau

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE AND THEN REGRID TO MDL
# MDL ARCHVIE GRID.
# (NON-PRECIP FIELDS) -- INTERPOLATION IS BILINEAR
#######################################################################
   export IOBUF_PARAMS=''
   $WGRIB2 $g2 > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_gfs_nonpcp.wgrib2 grib2.inv |
   $WGRIB2 -i $g2 -new_grid_winds grid -new_grid_interpolation bilinear \
                  -new_grid ${GRID} mdl.gfsxgmosak_f${tau}.$cycle.pgrb2
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
                  -append -new_grid ${GRID} mdl.gfsxgmosak_f${tau}.$cycle.pgrb2
   export err=$?; err_chk


   $GRB2INDEX mdl.gfsxgmosak_f${tau}.$cycle.pgrb2 mdl.gfsxgmosak_f${tau}.$cycle.pgrb2.index
   export err=$?; err_chk

   grep -B 1 "^......... ......... ......${tau}" $FIXgfs_mos/mdl_gfsxprepgmosak_grb2tomdlp.lst > mdl_gfsxprepgmosak_grb2tomdlp.f${tau}.lst
   printf "99999\n" >> mdl_gfsxprepgmosak_grb2tomdlp.f${tau}.lst

#######################################################################
# GRB2TOMDLP
# CONVERT GRIB2 TO TDLPACK FOR HOURS 0 TO 96
#######################################################################

   export IOBUF_PARAMS=''
   export pgm=mdl_grb2tomdlp
   . prep_step
   export FORT10="ncepdate"
   export FORT20="mdl.gfsxgmosak_f${tau}.$cycle.pgrb2"
   export FORT21="mdl.gfsxgmosak_f${tau}.$cycle.pgrb2.index"
   export FORT28="mdl_gfsxprepgmosak_grb2tomdlp.f${tau}.lst"
   export FORT29="$FIXcode/mdl_gridlst"
   export FORT30="$FIXcode/mdl_mos2000id.tbl"
   export FORT60="pkgfsxrawgmosak_f${tau}.$DAT"
   echo MDLLOG:  `date` - Program mdl_grb2tomdlp has begun
   startmsg
   $EXECcode/mdl_grb2tomdlp < $PARMgfs_mos/mdl_gfsgrb2tomdlp.cn >> $pgmout 2>errfile
   export err=$?; err_chk

   echo MDLLOG:  `date` - Program mdl_grb2tomdlp has ended

   cat pkgfsxrawgmosak_f${tau}.$DAT >> pkgfsxrawgmosak.$DAT.$projGroup

done  # for tau

echo MDLLOG: `date` - Job exgfsmos_akgoe_extprep has ended.
#######################################################################
