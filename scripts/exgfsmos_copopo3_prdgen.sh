#!/bin/sh
#
#######################################################################
#  Job Name: exgfsmos_copopo3_prdgen.sh 
#  Purpose: To run all steps necessary to create GFS-based gridded 
#           MOS 3-h Probability of Precipitation Occurrence (PoPO3)
#           fcsts on the CONUS 2.5 km NDFD Grid.
#
#  Remarks: None
#
#  HISTORY: 2012-05-31  Huntemann  New job for CONUS 2.5 km Gridded
#                                  MOS popo3.
#           2012-11-15  Huntemann  Adapted for Intel WCOSS
#           2013-04-03  Huntemann  Added check for model data. This
#                                  script will sleep up to 2 hours if
#                                  model data is not present.
#           2013-11-08  Huntemann  Adapted for operations.
#           2013-12-04  Scallion   Removed sleep. Copy input files into
#                                  working (DATA) directory.
#           2013-12-16  Shafer     Merged PoPO in with PoPO3.
#                                  Added Grib2 processing for PoPO.
#           2014-01-02  Shafer     Script was modifed to process 
#                                  short-range only.  Ext-range is
#                                  processed in a separate script.
#           2014-01-14  Engle      Replaced "fcst" with "prdgen" in
#                                  script name since it will alert GRIB2
#                                  files; Added tocgrib2super program
#                                  and dbn_alert commands.
#           2016-02-02  Scallion   Configured for MPMD
#           2019-07-26  Scallion   Removed dissemination of grids.    
#######################################################################
set -x
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'

echo MDLLOG: `date` - Begin job `basename $0`

cd $DATA/copopo3
cpreq $DATA/ncepdate .

#######################################################################
#  COPY THE GFS MODEL FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle . 

#
#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#              THIS RUN COMPUTES PREDICTORS FOR BOTH POPO AND POPO3.
#
#######################################################################
#
echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="mdl_gfspkd47.$cycle"
export FORT27="$FIXgfs_mos/mdl_ndfd2p5trim.tbl"
export FORT28="$FIXgfs_mos/mdl_gfspopocoprd.$cycle"  #PS 2013-12-12: Changed RF IDs to approved values
export FORT29="$FIXcode/mdl_mos2000id.tbl"  #PS 2013-12-12: Added approved RF IDs to table
export FORT44="$FIXgfs_mos/mdl_popoRF_conus2p5.grra"  #TLH 2013-11-08: should this be renamed?  PS 2013-12-12: File replaced (new IDs)
export FORT60="preds.$PDY$cyc"
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredpopo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - MOSPRED ended
#
#######################################################################
#
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                   CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                   CODE IS USED TO CREATE THE OPERATIONAL MOS
#                   FORECAST FILE.
#######################################################################
#
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE
export pgm=mdl_racreate
. prep_step
startmsg
export FORT50="mdl_gfspopo3_ra.$PDY$cyc"
$EXECcode/mdl_racreate < $PARMgfs_mos/mdl_gmosu350.cn >> $pgmout 2>errfile
export err=$?
echo MDLLOG: `date` - RACREATE ended
#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES RANDOM ACCESS FORECAST FILE
#
#######################################################################
#
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export pgm=mdl_rainit
. prep_step
startmsg
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_ndfd2p5trim.tbl"
export FORT49="mdl_gfspopo3_ra.$PDY$cyc"
$EXECcode/mdl_rainit < $PARMgfs_mos/mdl_gmosu351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - RAINIT ended
#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#
#######################################################################
#
echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS POPO/POPO3 FORECASTS
export pgm=mdl_eqneval
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="preds.$PDY$cyc"
export FORT27="$FIXgfs_mos/mdl_ndfd2p5trim.tbl"
export FORT28="$FIXgfs_mos/mdl_predtofcst.popo3" #TLH 2013-11-08 can this just be appended to mdl_predtofcst?  PS 2013-12-13: Added PoPO IDs
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gmoscopopo.04010930.$cycle"  #PS 2013-12-13 added PoPO warm season
export FORT31="$FIXgfs_mos/mdl_gmoscopopo.10010331.$cycle"  #PS 2013-12-13 added PoPO cool season
export FORT32="$FIXgfs_mos/mdl_gmoscopopo3.04010930.$cycle" #TLH 2013-11-08 should this be renamed?
export FORT33="$FIXgfs_mos/mdl_gmoscopopo3.10010331.$cycle" #TLH 2013-11-08 should this be renamed?
export FORT49="mdl_gfspopo3_ra.$PDY$cyc"
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevalpopo3.cn >> $pgmout 2>errfile   #PS 2013-12-13 Modified cn file to add PoPO equations
export err=$?; err_chk
echo MDLLOG: `date` - EQNEVAL ended
#
#######################################################################
#
#    PROGRAM FCSTPOST - NORMALIZES POPO/POPO3 PROBABILITY FORECASTS
#
#######################################################################
#
echo MDLLOG: `date` - begin job FCSTPOST - NORMALIZE POPO/POPO3 FORECASTS
export pgm=mdl_fcstpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_ndfd2p5trim.tbl"
export FORT28="$FIXgfs_mos/mdl_gfspostpopo.$cycle"  #PS 2013-12-13 Renamed ID file and merged in IDs for POPO
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfspopo3_ra.$PDY$cyc"
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostpopo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - FCSTPOST ended
#
#######################################################################
#
# PROGRAM VECT2GRID - CONVERTS RA "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_gfspopo3_grra.$PDY$cyc

echo MDLLOG: `date` - begin job VECT2GRID - CONVERT POPO3 VECTOR FILE TO GRIDDED
export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_ndfd2p5trim.lst"
export FORT27="$FIXgfs_mos/mdl_ndfd2p5sta.tbl"
export FORT31="$FIXgfs_mos/mdl_gfsvect2grid_popo.in.$cycle" 
export FORT32="$FIXgfs_mos/mdl_gfsvect2grid_popo.out.$cycle" 
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfspopo3_grra.$PDY$cyc"
export FORT48="mdl_gfspopo3_ra.$PDY$cyc"
export FORT60="mdl_gfspopo3_grsq.$PDY$cyc"
$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_copopo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - VECT2GRID ended
#
#######################################################################
#
# PROGRAM GRIDPOST - CONVERT POPO PROBS TO WHOLE PERCENT
#
#######################################################################
#
echo MDLLOG: `date` - begin job GRIDPOST FOR PTYPE
export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="mdl_gfspopo3_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_granlsta.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpostpopo.$cycle"  
export FORT29="$FIXcode/mdl_mos2000id.tbl"  #PS 2013-12-13 added ID for POPO(%) to table
export FORT30="mdl_gfsgrpostpopo_grsq.$PDY$cyc"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_popo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended
#
#######################################################################
#
# PROGRAM GRD2GRD - OUTPUT POPO(%) TO GRD RA FILE
#
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_gfsgrpostpopo_grra.$PDY$cyc

echo MDLLOG: `date` - begin job GRD2GRD - OUTPUT POPO TO GRRA FILE
export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"
export FORT25="mdl_gfsgrpostpopo_grsq.$PDY$cyc"
export FORT28="$FIXcode/mdl_mos2000id.tbl"
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd_popo.ids.$cycle"  
export FORT42="mdl_gfsgrpostpopo_grra.$PDY$cyc"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_co2p5.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
#
#######################################################################
# 
# PROGRAM RA2GRIB2 - CODES MOS POPO FORECASTS INTO GRIB2. 
#
#######################################################################
#
echo MDLLOG: `date` - begin job RA2GRIB2 for POPO short-range 
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1popo"
export FORT32="$FIXgfs_mos/mdl_gmoscowxgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmoscogb2sect4popo.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmoscogb2sect5popo.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgrpostpopo_grra.$PDY$cyc"
export FORT60="mdl_gmoscogb2popo.$cycle.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 
#
#######################################################################
#
# UTILITY TOCGRIB2SUPER - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                         INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                         ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#
#######################################################################
#
echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmoscogb2popo.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoscogb2popo.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoscogb2headpopo.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmoscogb2popo.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmoscogb2popo.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoscogb2popo.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoscogb2headpopo.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk
#
########################################################################
# COPY FILES TO COM
########################################################################

if test $SENDCOM = 'YES'
then
   cpfs mdl_gfspopo3_grsq.$PDY$cyc $COMOUT/mdl_gfspopo3_grsq.$cycle
   # SEND GRIB2 FILE WITH NO HEADERS TO $COMOUT
   cpfs mdl_gmoscogb2popo.$cycle.nohead $COMOUT/mdl_gmoscogb2popo.$cycle
fi

########################################################################
echo MDLLOG: `date` - End job `basename $0`
########################################################################
