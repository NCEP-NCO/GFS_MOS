#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_pac_extprep.sh.ecf
#  Purpose: This script extracts multiple fields from NCEP GFS pgrb2
#           (GRIB2) files. The fields are interpolated from 1.0 deg.
#           (projections 99-192) and 2.5 deg. (projections 204-384) 
#           lat/lon grid to MDL GFS Pacific Grid. This script uses 
#           NCEP utilities wgrib2, copygb2, and grb2index. 
#  Remarks:
#  HISTORY: Feb 10, 2016 SDS  - New script is the same as the old
#                               pac_extfcst script, just renamed withof 
#                               with additions for running in MPMD.
#           Feb 12, 2016 SDS  - Regrid with copygb2 rather than wgrib2,
#                               which runs slowly on the Cray.
#           Jan 23, 2017 SDS  - Only process 1 degree files, with 2.5
#                               going away for GFS_V14.  
#
#           Dec 7 2018        - change $COMINgfs to the new path that
#                               GFS-FV3v15 used as output
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_pac_extprep
set -x

cd $DATA/pac_prep
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

################################################################################
#  FIRST GATHER MODEL DATA AND PUT IN TDLPACK
#  LOOP THROUGH PROJECTIONS (00 THROUGH 96 ARE DONE IN GFSMOS_PAC_FCST)
################################################################################
for tau in $(seq -f %03g 99 3 192 && seq -f %03g 204 12 384)
do

######################################################################
# SET THE GRID SPECS FOR WGRIB2 AND COPY PGRIB2 FILE
#######################################################################
  GRID="$(grep '^GFS80PAC:' $FIXgfs_mos/mdl_wgrib2_gds | cut -d":" -f2-)"
  cp $COMINgfs/${cyc}/atmos/gfs.${cycle}.pgrb2.1p00.f${tau} gfs.$PDY$cyc.pgrb2f$tau

  if [ $? -ne 0 ]; then
     msg="WARNING: 1-DEG PGRB2 GFS FILE NOT FOUND FOR ${tau}"
     postmsg "$jlogfile" "$msg"
  fi  

  g2=gfs.$PDY$cyc.pgrb2f$tau

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE AND THEN REGRID TO MDL
# MDL ARCHVIE GRID.
# (NON-PRECIP FIELDS) -- INTERPOLATION IS BILINEAR
#######################################################################
   $WGRIB2 $g2 > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_pacgfs_nonpcp.wgrib2 grib2.inv | 
   $WGRIB2 -i $g2 -new_grid_winds grid -new_grid_interpolation bilinear \
                  -append -new_grid ${GRID} mdl.pacgfsx.$cycle.pgrb2
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
                  -append -new_grid ${GRID} mdl.pacgfsx.$cycle.pgrb2
   export err=$?; err_chk

done  # for tau

$GRB2INDEX mdl.pacgfsx.$cycle.pgrb2 mdl.pacgfsx.$cycle.pgrb2.index
export err=$?; err_chk

#######################################################################
# GRB2TOMDLP
# CONVERT GRIB2 TO TDLPACK FOR HOURS 0 TO 96
#######################################################################

export pgm=mdl_grb2tomdlp
. prep_step
export FORT10="ncepdate"
export FORT20="mdl.pacgfsx.$cycle.pgrb2"
export FORT21="mdl.pacgfsx.$cycle.pgrb2.index"
export FORT28="$FIXgfs_mos/mdl_pacgfsxprep_grb2tomdlp.lst"
export FORT29="$FIXcode/mdl_gridlst"
export FORT30="$FIXcode/mdl_mos2000id.tbl"
export FORT60="pacpkgfsxraw.$DAT"
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
  cpfs pacpkgfsxraw.$DAT $COMOUT/mdl_pacgfsxpkd.$cycle
fi

echo MDLLOG: `date` - Job gfsmos_pac_extprep has ended.
#######################################################################
