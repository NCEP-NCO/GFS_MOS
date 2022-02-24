#!/bin/sh
#
#######################################################################
#  Job Name: exgfsmos_akptype_prdgen.sh 
#  Purpose: To run all steps necessary to create GFS-based gridded 
#           MOS precipitation type fcsts on the 3 km Alaska Grid.
#
#  Remarks: None
#
#  HISTORY: 2012-08-24  Huntemann  New job for 3 km Alaska gridded
#                                  MOS ptype.
#           2012-11-15  Huntemann  Adapted for Intel WCOSS
#           2013-04-03  Huntemann  Added check for model data. This
#                                  script will sleep up to 2 hours if
#                                  model data is not present.
#           2013-11-15  Huntemann  Adapted for operations.
#           2013-12-04  Scallion   Removed sleeps. Copy input files to
#                                  working (DATA) directory.  
#           2013-12-12  Shafer     Added gridpost, grd2grd, and ra2grib2
#                                  runs to produce GRIB2 files.
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

cd $DATA/akptype
cpreq $DATA/ncepdate .

#######################################################################
#  COPY IN THE GFS MODEL DATA FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle .

#
#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#
#######################################################################
#
echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="mdl_gfspkd47.$cycle"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_gfsptypeakprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_ptypeCONST_alaska3km.grra"
export FORT60="preds.$PDY$cyc"
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredptype.cn >> $pgmout 2>errfile
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
export FORT50="mdl_gfsptype_ra.$PDY$cyc"
$EXECcode/mdl_racreate < $PARMgfs_mos/mdl_gmosu350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - RACREATE ended
#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES PTYPE RANDOM ACCESS FORECAST FILE
#
#######################################################################
#
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export pgm=mdl_rainit
. prep_step
startmsg
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT49="mdl_gfsptype_ra.$PDY$cyc"
$EXECcode/mdl_rainit < $PARMgfs_mos/mdl_gmosu351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - RAINIT ended
#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR PTYPE
#
#######################################################################
#
echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS PTYPE FORECASTS
export pgm=mdl_eqneval
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="preds.$PDY$cyc"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_predtofcst.ptype" #TLH 2013-11-15 can this just be appended to mdl_predtofcst?
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gmosakptype.09010615.$cycle"
export FORT31="$FIXgfs_mos/mdl_gmosakptype.06160831.$cycle"
export FORT49="mdl_gfsptype_ra.$PDY$cyc"
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevalptype.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - EQNEVAL ended
#
#######################################################################
#
#    PROGRAM FCSTPOST - NORMALIZES PTYPE PROBABILITY FORECASTS
#
#######################################################################
#
echo MDLLOG: `date` - begin job FCSTPOST - NORMALIZE PTYPE FORECASTS
export pgm=mdl_fcstpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_gfspostptype_norm.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfsptype_ra.$PDY$cyc"
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostnormptype.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - FCSTPOST ended
#
#######################################################################
#
#    PROGRAM FCSTPOST - CREATE CATEGORICAL PTYPE FORECASTS
#
#######################################################################
#
echo MDLLOG: `date` - begin job FCSTPOST - CATEGORICAL PTYPE FORECASTS
export pgm=mdl_fcstpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_akndfdtrimsta.tbl.popo3ptype"
export FORT28="$FIXgfs_mos/mdl_gfspostptype_cat.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT47="$FIXgfs_mos/mdl_ptypeAK_thresh.ra" #TLH 2013-11-15 name?
export FORT49="mdl_gfsptype_ra.$PDY$cyc"
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostcatptype.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - FCSTPOST ended
#
#######################################################################
#
# PROGRAM VECT2GRID - CONVERTS RA "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_gfsptype_grra.$PDY$cyc

echo MDLLOG: `date` - begin job VECT2GRID - CONVERT VECTOR RA FILE TO GRIDDED
export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_akndfdtrimsta.lst.popo3ptype"
export FORT27="$FIXgfs_mos/mdl_akndfd_u155.tbl.popo3ptype"
export FORT31="$FIXgfs_mos/mdl_gfsvect2grid_ptype.in.$cycle" 
export FORT32="$FIXgfs_mos/mdl_gfsvect2grid_ptype.out.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsptype_grra.$PDY$cyc"
export FORT48="mdl_gfsptype_ra.$PDY$cyc"
export FORT60="mdl_akgfsptype_grsq.$PDY$cyc"
$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_akptype.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - VECT2GRID ended
#
#######################################################################
#
# PROGRAM GRIDPOST - CONVERT PROBS TO WHOLE PERCENT
#                  - CONVERT BEST CATEGORIES TO WMO GRIB2 STANDARD
#
#######################################################################
#
echo MDLLOG: `date` - begin job GRIDPOST FOR PTYPE
export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="mdl_akgfsptype_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_granlsta.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpostptype.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="mdl_akgfsgrpostptype_grsq.$PDY$cyc"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_ptype.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended
#
#######################################################################
#
# PROGRAM GRD2GRD - THIS RUN OF GRD2GRD WILL OUTPUT THE FOLLOWING 
#                   INTO ONE RA FILE FOR INPUT TO RA2GRIB2:
#                   (1) COND PTYPE PRB(%) - OUTPUT FROM GRIDPOST
#                   (2) COND BEST CATEGORY(WMO) - OUTPUT FROM GRIDPOST
#
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_akgfsgrpostptype_grra.$PDY$cyc

echo MDLLOG: `date` - begin job GRD2GRD - OUTPUT PTYPE TO GRRA FILE
export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"
export FORT25="mdl_akgfsgrpostptype_grsq.$PDY$cyc"
export FORT28="$FIXcode/mdl_mos2000id.tbl"
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd_ptype.ids.$cycle"
export FORT42="mdl_akgfsgrpostptype_grra.$PDY$cyc"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_akndfd.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
#
#######################################################################
# 
# PROGRAM RA2GRIB2 - CODES TDLPACK MOS FORECASTS INTO GRIB2. 
#
#   WE'LL LOOP THROUGH THE FOLLOWING ELEMENTS, CREATING SEPARATE
#   GRIB2 FILES FOR EACH ELEMENT  
#
#   CPRBFZ = COND PROB FREEZING
#   CPRBSN = COND PROB SNOW
#   CPRBRA = COND PROB RAIN
#   CBESTC = COND BEST CATEGORY
#
#######################################################################
#
for element in cprbfz cprbsn cprbra cbestc
do

echo MDLLOG: `date` - begin job RA2GRIB2 for $elem short-range 
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1ptype"
export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmosakgb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosakgb2sect5ptype.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_akgfsgrpostptype_grra.$PDY$cyc"
export FORT60="mdl_gmosakgb2${element}.$cycle.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 

done
#
#######################################################################
# UTILITY TOCGRIB2SUPER - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                         INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                         ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#######################################################################
#
for element in cprbfz cprbsn cprbra cbestc
do

echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosakgb2${element}.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosakgb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosakgb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosakgb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosakgb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosakgb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosakgb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done
#
########################################################################
# COPY FILES TO COM
########################################################################

if test $SENDCOM = 'YES'
then
   cpfs mdl_akgfsptype_grsq.$PDY$cyc $COMOUT/mdl_akgfsptype_grsq.$cycle
   # SEND GRIB2 FILE WITH NO HEADERS TO $COMOUT
   cpfs mdl_gmosakgb2cprbfz.$cycle.nohead $COMOUT/mdl_gmosakgb2cprbfz.$cycle
   cpfs mdl_gmosakgb2cprbsn.$cycle.nohead $COMOUT/mdl_gmosakgb2cprbsn.$cycle
   cpfs mdl_gmosakgb2cprbra.$cycle.nohead $COMOUT/mdl_gmosakgb2cprbra.$cycle
   cpfs mdl_gmosakgb2cbestc.$cycle.nohead $COMOUT/mdl_gmosakgb2cbestc.$cycle
fi

#######################################################################
echo MDLLOG: `date` - End job `basename $0`
#######################################################################
