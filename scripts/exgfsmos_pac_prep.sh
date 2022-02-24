#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_pac_prep.sh.ecf
#  Purpose: This script extracts multiple fields from NCEP GFS pgrb2
#           (GRIB2) files. The fields are interpolated from 1.0 deg.
#           lat/lon grid to MDL GFS Pacific Grid. This script uses NCEP 
#           utilities wgrib2, copygb2, and grb2index and works on 
#           forecast projection 0 through 96.
#  Remarks: 
#  HISTORY: Jan 14, 2016 SDS  - Created new script by cutting model 
#                               prep portion out of PAC fcst script
#           Feb 12, 2016 SDS  - Regrid with copygb2 rather than wgrib2,
#                               which runs slowly on the Cray.
#
#           Dec 7 2018        - change $COMINgfs to the new path that
#                               GFS-FV3v15 used as output
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_pac_prep
set -x

cd $DATA/pac_prep
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

################################################################################
#  FIRST GATHER MODEL DATA AND PUT IN TDLPACK
#  LOOP THROUGH PROJECTIONS
################################################################################
for tau in $(seq -f %03g 0 3 96)
do

#######################################################################
# SET THE GRID SPECS FOR WGRIB2
#######################################################################
  GRID="$(grep '^GFS80PAC:' $FIXgfs_mos/mdl_wgrib2_gds | cut -d":" -f2-)"

#######################################################################
# COPY 1.0 DEG. GLOBAL LAT/LON GRIB2 FILES FROM COM
#######################################################################
   cp $COMINgfs/${cyc}/atmos/gfs.${cycle}.pgrb2.1p00.f${tau} gfs.$PDY$cyc.pgrb2f$tau

   if [ $? -ne 0 ]; then
      msg="WARNING: 1-DEG PGRB2 GFS FILE NOT FOUND FOR ${tau}"
      postmsg "$jlogfile" "$msg"
   fi  

   g2="gfs.$PDY$cyc.pgrb2f$tau"

#######################################################################
# RUN WGRIB2 TO PARSE OUT FIELDS TO ARCHIVE AND THEN REGRID TO MDL
# MDL ARCHVIE GRID.
# (NON-PRECIP FIELDS) -- INTERPOLATION IS BILINEAR
#######################################################################
   $WGRIB2 $g2 > grib2.inv
   export err=$?; err_chk

   grep -f $FIXgfs_mos/mdl_pacgfs_nonpcp.wgrib2 grib2.inv | 
   $WGRIB2 -i $g2 -new_grid_winds grid -new_grid_interpolation bilinear \
                  -append -new_grid ${GRID} mdl.pacgfs.$cycle.pgrb2
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
                  -append -new_grid ${GRID} mdl.pacgfs.$cycle.pgrb2
   export err=$?; err_chk

done  # for tau

$GRB2INDEX mdl.pacgfs.$cycle.pgrb2 mdl.pacgfs.$cycle.pgrb2.index
export err=$?; err_chk

#######################################################################
# GRB2TOMDLP
# CONVERT GRIB2 TO TDLPACK FOR HOURS 0 TO 96
#######################################################################

export pgm=mdl_grb2tomdlp
. prep_step
export FORT10="ncepdate"
export FORT20="mdl.pacgfs.$cycle.pgrb2"
export FORT21="mdl.pacgfs.$cycle.pgrb2.index"
export FORT28="$FIXgfs_mos/mdl_pacgfsprep_grb2tomdlp.lst"
export FORT29="$FIXcode/mdl_gridlst"
export FORT30="$FIXcode/mdl_mos2000id.tbl"
export FORT60="pac_pkgfsraw.$DAT"
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
  cpfs pac_pkgfsraw.$DAT $COMOUT/mdl_pacgfspkd.$cycle
fi

echo MDLLOG: `date` - Job gfsmos_pac_prep has ended.
#######################################################################
