#!/bin/sh
#
#######################################################################
#  Job Name: exgfsmos_akpopo3_extprdgen.sh 
#  Purpose: To run all steps necessary to create GFS-based gridded 
#           MOS 3-h Probability of Precipitation Occurrence (PoPO3)
#           fcsts on the 3 km Alaska grid.
#
#  Remarks: None
#
#  HISTORY: 2014-01-02  Shafer     Script was created to process 
#                                  ext-range PoPO/PoPO3.  Short-range
#                                  is processed in a separate script.
#           2014-01-14  Engle      Replaced "fcst" with "prdgen" in 
#                                  script name since it will alert GRIB2
#                                  files; Added tocgrib2super program
#                                  and dbn_alert commands.
#           2016-02-10  Scallion   Configured for MPMD
#           2016-04-13  G.Wagner   Adjusted const file for GRANALYSIS.
#           2019-07-26  Scallion   Removed dissemination of grids.    
#######################################################################
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'

echo MDLLOG: `date` - Begin job `basename $0`
set -x

cd $DATA/akpopo3
cpreq $DATA/ncepdate .

#######################################################################
#  COPY IN THE GFS MODEL DATA FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle .
cpreq $COMIN/mdl_gfsxpkd47.$cycle .

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
export FORT25="mdl_gfsxpkd47.$cycle"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_gfsxpopoakprd.$cycle"  #PS 2013-12-12: Changed RF IDs to approved values
export FORT29="$FIXcode/mdl_mos2000id.tbl"  #PS 2013-12-12: Added approved RF IDs to table
export FORT44="$FIXgfs_mos/mdl_popoRF_alaska.grra"  #TLH 2013-11-14 name?  PS 2013-12-12: File replaced (new IDs)
export FORT60="predsx.$PDY$cyc"
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxpredpopo.cn >> $pgmout 2>errfile
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
export FORT50="mdl_gfsxpopo3_ra.$PDY$cyc"
$EXECcode/mdl_racreate < $PARMgfs_mos/mdl_gmosu350.cn >> $pgmout 2>errfile
export err=$?; err_chk
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
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT49="mdl_gfsxpopo3_ra.$PDY$cyc"
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
export FORT24="predsx.$PDY$cyc"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_predtofcst.popo3" #TLH 2013-11-14 name?  PS 2013-12-13: Added IDs for PoPO
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gmosxakpopo.04010930.$cycle"  #PS 2013-12-13 added PoPO warm season
export FORT31="$FIXgfs_mos/mdl_gmosxakpopo.10010331.$cycle"  #PS 2013-12-13 added PoPO cool season
export FORT32="$FIXgfs_mos/mdl_gmosxakpopo3.04010930.$cycle"
export FORT33="$FIXgfs_mos/mdl_gmosxakpopo3.10010331.$cycle"
export FORT49="mdl_gfsxpopo3_ra.$PDY$cyc"
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevalpopo3.cn >> $pgmout 2>errfile  #PS 2013-12-13 Added PoPO to control file
export err=$?
echo MDLLOG: `date` - EQNEVAL ended
#
#######################################################################
#
#    PROGRAM FCSTPOST - NORMALIZES POPO/POPO3 PROBABILITY FORECASTS
#
#######################################################################
#
echo MDLLOG: `date` - begin job FCSTPOST - NORMALIZE POPO3 FORECASTS
export pgm=mdl_fcstpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_gfsxpostpopo.$cycle"  #PS 2013-12-13 Renamed ID file and merged in IDs for POPO
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfsxpopo3_ra.$PDY$cyc"
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostpopo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - FCSTPOST ended
#
#######################################################################
#
# PROGRAM VECT2GRID - CONVERTS RA "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.
#
# NOTE: THIS RUN OF VECT2GRID CONVERTS THE VECTOR POPO/POPO3 FORECASTS
#       TO GRIDDED FORMAT FOR USE AS A "FIRST GUESS" IN U155.
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_gfsxpopo3_grra_u155fg.$PDY$cyc

echo MDLLOG: `date` - begin job VECT2GRID - CONVERT POPO3 VECTOR TO GRIDDED
export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_akndfdtrimsta.lst.popo3ptype"
export FORT27="$FIXgfs_mos/mdl_akndfd_u155.tbl.popo3ptype"
export FORT31="$FIXgfs_mos/mdl_gfsxvect2grid_popo.in.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxvect2grid_popo.fg.$cycle"  
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsxpopo3_grra_u155fg.$PDY$cyc"
export FORT48="mdl_gfsxpopo3_ra.$PDY$cyc"
export FORT60="mdl_gfsxpopo3_grsq_u155fg.$PDY$cyc"
$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_akpopo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - VECT2GRID ended
#
#######################################################################
#
# PROGRAM GRANALYSIS - ANALYZE POPO/POPO3 FORECASTS TO ALASKA 3KM GRID
#                      (THIS IS REALLY JUST RUNNING A SMOOTHER)
#
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_akgfsxpopo3_grra.$PDY$cyc

echo MDLLOG: `date` - begin job GRANALYSIS
export pgm=mdl_granalysis_ak
. prep_step
startmsg
export FORT10="ncepdate"
export FORT30="mdl_gfsxpopo3_grsq_u155fg.$PDY$cyc"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_akwx"
export FORT42="mdl_akgfsxpopo3_grra.$PDY$cyc"
export FORT31="mdl_akgfsxpopo3_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_granlsta.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta.tbl"
export FORT38="$FIXgfs_mos/mdl_gfsxpopogranlids_ak.$cycle"  #PS 2013-12-13 Added IDs for PoPO
export FORT51="$FIXgfs_mos/mdl_u405apopoakcn"  #PS 2013-12-13 u405a control file for PoPO
export FORT52="$FIXgfs_mos/mdl_u405apopo3akcn"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
$EXECcode/mdl_granalysis_ak < $PARMgfs_mos/mdl_granalysis_akpopo3.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS ended
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
export FORT24="mdl_akgfsxpopo3_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_granlsta.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgrpostpopo.$cycle"  
export FORT29="$FIXcode/mdl_mos2000id.tbl"  #PS 2013-12-13 added ID for POPO(%) to table
export FORT30="mdl_akgfsxgrpostpopo_grsq.$PDY$cyc"
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
cpreq $FIXcode/mdl_rafile_template mdl_akgfsxgrpostpopo_grra.$PDY$cyc

echo MDLLOG: `date` - begin job GRD2GRD - OUTPUT POPO TO GRRA FILE
export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"
export FORT25="mdl_akgfsxgrpostpopo_grsq.$PDY$cyc"
export FORT28="$FIXcode/mdl_mos2000id.tbl"
export FORT27="$FIXgfs_mos/mdl_gfsxgrd2grd_popo.ids.$cycle"
export FORT42="mdl_akgfsxgrpostpopo_grra.$PDY$cyc"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_akndfd.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
#
#######################################################################
# 
# PROGRAM RA2GRIB2 - CODES MOS POPO FORECASTS INTO GRIB2. 
#
#######################################################################
#
echo MDLLOG: `date` - begin job RA2GRIB2 for POPO ext-range 
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1popo"
export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmosxakgb2sect4popo.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosxakgb2sect5popo.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_akgfsxgrpostpopo_grra.$PDY$cyc"
export FORT60="mdl_gmosxakgb2popo.$cycle.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
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
export FORT11="mdl_gmosxakgb2popo.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxakgb2popo.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxakgb2headpopo.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosxakgb2popo.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxakgb2popo.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxakgb2popo.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxakgb2headpopo.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk
#
########################################################################
# COPY FILES TO COM
########################################################################

if test $SENDCOM = 'YES'
then
   cpfs mdl_akgfsxpopo3_grsq.$PDY$cyc $COMOUT/mdl_akgfsxpopo3_grsq.$cycle
   # SEND GRIB2 FILE WITH NO HEADERS TO $COMOUT
   cpfs mdl_gmosxakgb2popo.$cycle.nohead $COMOUT/mdl_gmosxakgb2popo.$cycle
fi

#######################################################################
echo MDLLOG: `date` - End job `basename $0`
#######################################################################
