      PROGRAM SSTINT
      USE MOD_ZA  ! HYCOM array I/O interface
      IMPLICIT NONE
C
C     DEFINE INPUT CLIMATOLOGY GRID.
C
C     SETUP FOR 1.0 DEGREE REYNOLDS & SMITH GLOBAL CLIMATOLOGY.
C
      INTEGER    IWI,JWI
      REAL*4     XFIN,YFIN,DXIN,DYIN
      PARAMETER (IWI=360, JWI=180)
      PARAMETER (XFIN=  0.5, DXIN=1.0)
      PARAMETER (YFIN=-89.5, DYIN=1.0)
C
C     CLIM ARRAYS.
C
      INTEGER, ALLOCATABLE :: MSK(:,:)
      REAL*4,  ALLOCATABLE :: PLON(:,:),PLAT(:,:),XAF(:,:),YAF(:,:)
      REAL*4,  ALLOCATABLE :: TM(:,:)
C
      REAL*4    XAMAX,XAMIN,YAMAX,YAMIN
      REAL*4    QSEAIN(IWI,JWI)
      CHARACTER PREAMBL(5)*79
C
C     HDF I/O ARRAYS.
C
      INTEGER         IERR,IRANK,IFLIP(2),ISHAPE(2),ISLICE(2,2),NDSDS
      CHARACTER*(256) CHDFD,CHDFT,CHDFS,
     +                CHTITLE,CSUNIT,CSFORM,COORDSYS,CLABELS(2),
     +                CAUNITS(2),CAFORMS(2)
      REAL*4          SDSMIN,SDSMAX,AXES(IWI,2)
C
C     INTERPOLATION ARRAYS.
C
      INTEGER IBD(4)
      REAL*4  QSEAI(IWI+4,JWI+4)
      REAL*4  FXI(IWI+4),FYI(JWI+4),
     +        WQSEA3(IWI+4,JWI+4,3),WK(3*(IWI+JWI+8)+1)
C
C     NAMELIST.
C
      INTEGER          JPR
      COMMON/NPROCS/   JPR
      SAVE  /NPROCS/
C
      CHARACTER*40     CTITLE
      NAMELIST/AFTITL/ CTITLE
      INTEGER          INTERP,MONTH,ITEST,JTEST
      NAMELIST/AFFLAG/ INTERP,MONTH,ITEST,JTEST,JPR
C
C**********
C*
C 1)  FROM UNFORMATTED SST DATA ON ITS NATIVE GRID, CREATE A
C      FORMATTED MODEL GRID SST FILE SUITABLE FOR INPUT TO THE
C      HYCOM ISOPYCNAL CLIMATOLOGY GENERATOR OVER THE GIVEN REGION.
C
C     INTERPOLATION IS EITHER PIECEWISE BILINEAR OR CUBIC SPLINE.
C
C 2)  PARAMETERS:
C
C     NATIVE CLIM GRID SPECIFICATION, SEE (4):
C
C        IWI    = 1ST DIMENSION OF CLIM GRID
C        JWI    = 2ND DIMENSION OF CLIM GRID
C        XFIN   = LONGITUDE OF 1ST CLIM GRID POINT
C        YFIN   = LATITUDE  OF 1ST CLIM GRID POINT
C        DXIN   = CLIM LONGITUDINAL GRID SPACING
C        DYIN   = CLIM LATITUDINAL  GRID SPACING
C
C 3)  NAMELIST INPUT:
C
C     /AFTITL/
C        CTITLE - ONE (40-CHARACTER) LINE TITLE.
C
C     /AFFLAG/
C        INTERP - INTERPOLATION FLAG.
C                   =0; PIECEWISE LINEAR
C                   =1; CUBIC SPLINE (DEFAULT)
C        MONTH  - MONTH OF CLIMATOLOGY (1 TO 12)
C        ITEST  - 1ST ARRAY INDEX FOR DIAGNOSTIC PRINTOUT
C                   =0; NO DIAGNOSTIC PRINTOUT
C        JTEST  - 2ND ARRAY INDEX FOR DIAGNOSTIC PRINTOUT
C                   =0; NO DIAGNOSTIC PRINTOUT
C
C 4)  INPUT:
C        ON UNIT  5: NAMELIST /AFTITL/, /AFTIME/
C        HDF NATIVE SST  CLIM FILE, SEE (5).
C     OUTPUT:
C        ON UNIT 11:    UNFORMATTED MODEL    CLIM FILE, SEE (6).
C
C 5)  THE INPUT CLIM FIELD, VIA HDF, IS ON THE 'NATIVE' LAT-LON
C      GRID, STARTING AT THE POINT 'XFIN' EAST AND 'YFIN' NORTH WITH 
C      'YFIN' NORTH WITH GRIDSIZE 'DXIN' BY 'DYIN' DEGREES.  THE
C      INPUT ARRAY SIZE IS 'IWI' BY 'JWI', AND THERE ARE NO REPEATED
C      NODES (EVEN FOR GLOBAL DATA SETS).
C
C     ALL SST FIELDS MUST BE DEFINED AT EVERY GRID POINT,
C      INCLUDING LAND AND BELOW THE OCEAN FLOOR.
C
C 6)  THE OUTPUT SST IS AT EVERY GRID POINT OF THE MODEL'S 'P' GRID.
C     ARRAY SIZE IS 'IDM' BY 'JDM'.
C
C 7)  SEVERAL STATISTICS ARE WRITTEN OUT IN ORDER TO CHECK THE 
C      INTERPOLATION BETWEEN VARIOUS MACHINES.  MIN, MAX, MEAN AND RMS 
C      OF THE ENTIRE BASIN ARE OUTPUT FOR SST AND FOR EACH 
C      RECORD.  NOTE HOWEVER THAT THESE VALUES MAY NOT REPRESENT THE
C      STATISTICS OF THE CLIMS AS SEEN BY THE MODEL, IF THE INPUT CLIM 
C      DATA HAS NON-REALISTIC VALUES OVER LAND.  IT IS UP TO THE USER 
C      TO CHECK THE LOG FILES FOR CONSISTENCY BETWEEN MACHINES.
C
C 8)  ALAN J. WALLCRAFT,  PLANNING SYSTEMS INC.,  OCTOBER 1995.
C      BASED ON EARILER VERSIONS BY SEVERAL AUTHORS.
C*
C**********
C
      EXTERNAL LINEAR, AVERMS,MINMAX
C
      REAL*4     ZERO,RADIAN
      PARAMETER (ZERO=0.0, RADIAN=57.2957795)
      REAL*8     DZERO,DTHIRD
      PARAMETER (DZERO=0.D0,DTHIRD=1.D0/3.D0)
C
      CHARACTER*80 CLINE
      REAL*4  HMINA,HMINB,HMAXA,HMAXB
C
      INTEGER I,IWIX,J
      REAL*4  XFD,YFD,DXD,DYD
      REAL*4  XLIN,XFDX,XOV,YOU,
     +        XMIN,XMAX,XAVE,XRMS
C
      INTEGER      LEN_TRIM
      CHARACTER*11 CMONTH(12)
      DATA CMONTH /  ', January',
     +               ', February',
     +               ', March',
     +               ', April',
     +               ', May',
     +               ', June',
     +               ', July',
     +               ', August',
     +               ', September',
     +               ', October',
     +               ', November',
     +               ', December'  /
C
C --- MODEL ARRAYS.
C
      CALL XCSPMD  !define idm,jdm
      ALLOCATE(  MSK(IDM,JDM) )
      ALLOCATE( PLON(IDM,JDM) )
      ALLOCATE( PLAT(IDM,JDM) )
      ALLOCATE(  XAF(IDM,JDM) )
      ALLOCATE(  YAF(IDM,JDM) )
      ALLOCATE(   TM(IDM,JDM) )
C
C     NAMELIST INPUT.
C
      CALL ZHOPEN(6, 'FORMATTED', 'UNKNOWN', 0)
C
      CTITLE = ' '
      WRITE(6,*) 'READING /AFTITL/'
      CALL ZHFLSH(6)
      READ( 5,AFTITL)
      WRITE(6,AFTITL)
C
      INTERP = 1
      MONTH  = 1
      ITEST  = 0
      JTEST  = 0
      JPR    = 8
      WRITE(6,*) 'READING /AFFLAG/'
      CALL ZHFLSH(6)
      READ( 5,AFFLAG)
      WRITE(6,AFFLAG)
      WRITE(6,*)
      CALL ZHFLSH(6)
C
C     GRID INPUT.
C
      CALL ZAIOST
C
      CALL ZHOPNC(21, 'regional.grid.b', 'FORMATTED', 'OLD', 0)
      CALL ZAIOPF('regional.grid.a', 'OLD', 21)
C
      READ(21,*) ! skip idm
      READ(21,*) ! skip jdm
      READ(21,*) ! skip mapflg
      READ(21,'(A)') CLINE
      I = INDEX(CLINE,'=')
      READ (CLINE(I+1:),*)   HMINB,HMAXB
      CALL ZAIORD(PLON,MSK,.FALSE., HMINA,HMAXA, 21)
      IF     (ABS(HMINA-HMINB).GT.ABS(HMINB)*1.E-4 .OR.
     &        ABS(HMAXA-HMAXB).GT.ABS(HMAXB)*1.E-4     ) THEN
        WRITE(6,'(/ a / a,1p3e14.6 / a,1p3e14.6 /)')
     &    'error - .a and .b grid files not consistent (plon):',
     &    '.a,.b min = ',HMINA,HMINB,HMINA-HMINB,
     &    '.a,.b max = ',HMAXA,HMAXB,HMAXA-HMAXB
        CALL ZHFLSH(6)
        STOP
      ENDIF
C
      READ(21,'(A)') CLINE
      I = INDEX(CLINE,'=')
      READ (CLINE(I+1:),*)   HMINB,HMAXB
      CALL ZAIORD(PLAT,MSK,.FALSE., HMINA,HMAXA, 21)
      IF     (ABS(HMINA-HMINB).GT.ABS(HMINB)*1.E-4 .OR.
     &        ABS(HMAXA-HMAXB).GT.ABS(HMAXB)*1.E-4     ) THEN
        WRITE(6,'(/ a / a,1p3e14.6 / a,1p3e14.6 /)')
     &    'error - .a and .b grid files not consistent (plat):',
     &    '.a,.b min = ',HMINA,HMINB,HMINA-HMINB,
     &    '.a,.b max = ',HMAXA,HMAXB,HMAXA-HMAXB
        CALL ZHFLSH(6)
        STOP
      ENDIF
C
      CLOSE(UNIT=21)
      CALL ZAIOCL(21)
C
C     INITIALIZE OUTPUT.
C
      CTITLE = CTITLE(1:LEN_TRIM(CTITLE)) // CMONTH(MONTH)
      WRITE(6,6000) 'OUTPUT:',CTITLE
      CALL ZHFLSH(6)
C
      CALL ZAIOPN('NEW', 10)
C
      CALL ZHOPEN(10, 'FORMATTED', 'NEW', 0)
C
      PREAMBL(1) = CTITLE
      PREAMBL(2) = 'Sea Surface Temperature'
      PREAMBL(3) = ' '
      PREAMBL(4) = ' '
      WRITE(PREAMBL(5),'(A,2I5)')
     +        'i/jdm =',
     +       IDM,JDM
      WRITE(10,4101) PREAMBL
C
      WRITE(6,*)
      WRITE(6, 4101) PREAMBL
      WRITE(6,*)
C
C     INITIALIZE CLIMS.
C
      CALL GETENV('RS_SST', CHDFT)
      WRITE(6,*)
      WRITE(6,*) 'RS_SST  = ',TRIM(CHDFT)
      CALL ZHFLSH(6)
      CALL SDSRINFO(2,IRANK,ISHAPE,
     +              SDSMIN,SDSMAX,CHTITLE,CSUNIT,CSFORM,COORDSYS,
     +              AXES,IWI,CLABELS,CAUNITS,CAFORMS,
     +              CHDFT,1, IERR)
      IF     (IERR.NE.0) THEN
        CALL SDSIERR(IERR,'SDSSLICE - TEMP')
      ENDIF
      IF     (ISHAPE(1).NE.IWI .OR.
     +        ISHAPE(2).NE.JWI .OR.
     +        ABS(AXES(  1,1)-XFIN).GT.0.01 .OR.
     +        ABS(AXES(JWI,2)-YFIN).GT.0.01 .OR.
     +        ABS(ABS(AXES(2,1)-AXES(1,1))-DXIN).GT.0.01 .OR.
     +        ABS(ABS(AXES(2,2)-AXES(1,2))-DYIN).GT.0.01     ) THEN
        WRITE(6,9000) 'SST ',IWI,JWI,XFIN,YFIN,DXIN,DYIN
        WRITE(6,*) 'ISHAPE = ',ISHAPE
        WRITE(6,*) 'AXES.1 = ',AXES(1,1),AXES(2,1)
        WRITE(6,*) 'AXES.2 = ',AXES(1,2),AXES(2,2)
        CALL ZHFLSH(6)
        STOP
      ENDIF
C
C     DEFINE THE GRID COORDINATES.
C
      IF     (IWI*DXIN.GE.359.9) THEN
        IF     (ABS(IWI * DXIN - 360.0) .GT. 0.01) THEN
          WRITE(6,9050)
          CALL ZHFLSH(6)
          STOP
        ENDIF
        IWIX = IWI + 1
        IBD(1) = 3
        IBD(2) = 3
        IBD(3) = 2
        IBD(4) = 2
      ELSE
        IWIX = IWI
        IBD(1) = 2
        IBD(2) = 2
        IBD(3) = 2
        IBD(4) = 2
      ENDIF
C
C     CONVERT HYCOM LON,LAT TO CLIMATOLOGY ARRAY COORDS.
C
      XLIN  = XFIN + (IWIX-1)*DXIN
      XAMIN = 2*IWI
      XAMAX = 0
      DO J= 1,JDM
        DO I= 1,IDM
          XOV = PLON(I,J)
          IF     (XOV.LT.XFIN) THEN
            XOV = XOV + 360.0
          ELSEIF (XOV.GE.XLIN) THEN
            XOV = XOV - 360.0
          ENDIF
C
          XAF(I,J) = 3.0 + (XOV - XFIN)/DXIN
C
          IF     (MOD(J,100).EQ.1 .OR. J.EQ.JDM) THEN
            IF     (MOD(I,10).EQ.1 .OR. I.EQ.IDM) THEN
              WRITE(6,'("I,J,LONV,XAF =",2I5,2F10.3)') I,J,XOV,XAF(I,J)
            ENDIF
          ENDIF
          XAMIN  = MIN( XAMIN, XAF(I,J) )
          XAMAX  = MAX( XAMAX, XAF(I,J) )
        ENDDO
      ENDDO
C
      YAMIN = 2*JWI
      YAMAX = 0
      DO I= 1,IDM
        DO J= 1,JDM
          YOU = PLAT(I,J)
C
          YAF(I,J) = 3.0 + (YOU - YFIN)/DYIN
C
          IF     (MOD(I,100).EQ.1 .OR. I.EQ.IDM) THEN
            IF     (MOD(J,10).EQ.1 .OR. J.EQ.JDM) THEN
              WRITE(6,'("I,J,LATU,YAF =",2I5,2F10.3)') I,J,YOU,YAF(I,J)
            ENDIF
          ENDIF
          YAMIN  = MIN( YAMIN, YAF(I,J) )
          YAMAX  = MAX( YAMAX, YAF(I,J) )
        ENDDO
      ENDDO
C
      WRITE(6,6200) XAMIN,XAMAX,YAMIN,YAMAX
      CALL ZHFLSH(6)
C
C     CHECK THAT THE INTERPOLATION IS 'SAFE',
C
      IF     (INT(XAMIN).LT.3 .OR. INT(XAMAX).GT.IWI+2 .OR.
     +        INT(YAMIN).LT.3 .OR. INT(YAMAX).GT.JWI+2     ) THEN
        WRITE(6,9150)
        CALL ZHFLSH(6)
        STOP
      ENDIF
C
C       READ THE INPUT CLIMS.
C
        ISLICE(1,1) =    1
        ISLICE(2,1) =  IWI
        ISLICE(1,2) =    1
        ISLICE(2,2) =  JWI
        IFLIP(1)    =    1
        IFLIP(2)    =    1
        NDSDS       = IWI*JWI
C
        CALL SDSSLICE(QSEAIN,NDSDS,2,IRANK,ISHAPE,IFLIP,ISLICE,
     +                SDSMIN,SDSMAX,CHTITLE,CSUNIT,CSFORM,COORDSYS,
     +                AXES,IWI,CLABELS,CAUNITS,CAFORMS,
     +                CHDFT,1, IERR)
        IF     (IERR.NE.0) THEN
          CALL SDSIERR(IERR,'SDSSLICE - SST ')
        ENDIF
C
C       COPY INTO THE (LARGER) INTERPOLATION ARRAYS.
C
        DO 310 J= 1,JWI
          DO 311 I= 1,IWI
            QSEAI(I+2,J+2) = QSEAIN(I,J)
  311     CONTINUE
  310   CONTINUE
C
C       FILL IN THE PADDING AREA AS NECESSARY.
C
        IF     (INT(XAMAX).GE.IWI+1) THEN
          IF     (IWIX.GT.IWI) THEN
            DO 320 J= 3,JWI+2
              QSEAI(IWI+3,J) = QSEAI(3,J)
              QSEAI(IWI+4,J) = QSEAI(4,J)
  320       CONTINUE
          ELSE
            DO 325 J= 3,JWI+2
              QSEAI(IWI+3,J) = 2.0*QSEAI(IWI+2,J) -     QSEAI(IWI+1,J)
              QSEAI(IWI+4,J) = 3.0*QSEAI(IWI+2,J) - 2.0*QSEAI(IWI+1,J)
  325       CONTINUE
          ENDIF
        ENDIF
        IF     (INT(XAMIN).LE.3) THEN
          IF     (IWIX.GT.IWI) THEN
            DO 330 J= 3,JWI+2
              QSEAI(1,J) = QSEAI(IWI+1,J)
              QSEAI(2,J) = QSEAI(IWI+2,J)
  330       CONTINUE
          ELSE
            DO 335 J= 3,JWI+2
              QSEAI(1,J) = 3.0*QSEAI(3,J) - 2.0*QSEAI(4,J)
              QSEAI(2,J) = 2.0*QSEAI(3,J) -     QSEAI(4,J)
  335       CONTINUE
          ENDIF
        ENDIF
        IF     (INT(YAMAX).GE.JWI+1) THEN
          DO 340 I= 1,IWI+4
            QSEAI(I,JWI+3) = 2.0*QSEAI(I,JWI+2) -     QSEAI(I,JWI+1)
            QSEAI(I,JWI+4) = 3.0*QSEAI(I,JWI+2) - 2.0*QSEAI(I,JWI+1)
  340     CONTINUE
        ENDIF
        IF     (INT(YAMIN).LE.3) THEN
          DO 350 I= 1,IWI+4
            QSEAI(I,1) = 3.0*QSEAI(I,3) - 2.0*QSEAI(I,4)
            QSEAI(I,2) = 2.0*QSEAI(I,3) -     QSEAI(I,4)
  350     CONTINUE
        ENDIF
C
C       INTERPOLATE FROM NATIVE TO MODEL CLIM GRIDS.
C       ALSO INFORCE A STABLE DENSITY PROFILE.
C
        IF     (INTERP.EQ.0) THEN
          CALL LINEAR(TM,XAF,YAF,IDM,IDM,JDM,
     +                QSEAI,IWI+4,IWI+4,JWI+4)
        ELSE
          CALL CUBSPL(TM,XAF,YAF,IDM,IDM,JDM,
     +                QSEAI,IWI+4,IWI+4,JWI+4, IBD, FXI,FYI,WQSEA3,WK)
        ENDIF
C
C       ASSUME ICE FORMS (I.E. MIN SST) AT -1.8 DEGC.
C
        DO J= 1,JDM
          DO I= 1,IDM
            TM(I,J) = MAX( TM(I,J), -1.8 )
          ENDDO
        ENDDO
C
C       WRITE OUT STATISTICS.
C
        CALL MINMAX(TM,IDM,JDM, XMIN,XMAX)
        CALL AVERMS(TM,IDM,JDM, XAVE,XRMS)
        WRITE(6,8100) 'TSEA', XMIN,XMAX,XAVE,XRMS
C
C       DIAGNOSTIC PRINTOUT.
C
        IF     (MIN(ITEST,JTEST).GT.0) THEN
          WRITE(6,*)
          WRITE(6,'(A,2I5,A,F6.2)')
     +      'I,J =',ITEST,JTEST,
     +      '   SST =',TM(ITEST,JTEST)
          WRITE(6,*)
          CALL ZHFLSH(6)
        ENDIF
C
C       WRITE OUT HYCOM CLIMS.
C
        CALL ZAIOWR(TM,MSK,.FALSE., XMIN,XMAX, 10, .FALSE.)
        WRITE(10,4102) 'sea surface temperature',XMIN,XMAX
C
      CALL ZAIOCL(10)
      CLOSE( UNIT=10)
C
C     SUMMARY.
C
      WRITE(6,6400)
      CALL ZHFLSH(6)
      STOP
C
 4101 FORMAT(A79)
 4102 FORMAT(A,': range = ',1P2E16.7)
 6000 FORMAT(1X,A,2X,A40 //)
 6200 FORMAT(/ 1X,'MIN,MAX I COORDS = ',F8.2,',',F8.2 
     +       / 1X,'MIN,MAX J COORDS = ',F8.2,',',F8.2 /)
 6400 FORMAT(' SST CLIMATOLOGY COMPLETED.')
 8100 FORMAT(1X,A,': MIN=',F13.8,' MAX=',F13.8,
     +             ' AVE=',F13.8,' RMS=',F13.8)
 9000 FORMAT(// 20X,'*****  ERROR READING ',A,' -',
     +   ' INPUT DOES NOT AGREE WITH PARAMETERS  *****' //
     +   1X,'IWI,JWI   = ',I5,  I10,  /
     +   1X,'XFIN,YFIN = ',F8.2,F10.2 /
     +   1X,'DXIN,DYIN = ',F9.3, F9.3 //)
 9050 FORMAT(// 20X,'**********  ERROR - ',
     +   'INPUT IS GLOBAL AND IWI*DXIN IS NOT 360 DEGREES  ****' //)
 9150 FORMAT(// 20X,'**********  ERROR - ',
     +   'THE OUTPUT GRID IS NOT INSIDE THE INPUT GRID  **********' //)
C     END OF PROGRAM WNDINT.
      END
      SUBROUTINE SDSIERR(IERR,CNAME)
      IMPLICIT NONE
      INTEGER       IERR
      CHARACTER*(*) CNAME
C
C     HDF ERROR MESSAGES.
C
      WRITE(6,*)
      WRITE(6,*) 'ERROR FROM ',CNAME
      IF     (IERR.GT.0) THEN
        WRITE(6,*) 'WARNING - SOME HDF TAGS MISSING'
        WRITE(6,*)
      ELSEIF (IERR.EQ.-1) THEN
        WRITE(6,*) 'ERROR - FEWER THAN ISDS SDSs'
        WRITE(6,*)
        CALL EXIT(1)
      ELSEIF (IERR.EQ.-3) THEN
        WRITE(6,*) 'ERROR - MRANK (2)  TOO SMALL'
        WRITE(6,*)
        CALL EXIT(1)
      ELSEIF (IERR.EQ.-4) THEN
        WRITE(6,*) 'ERROR - MDAXES (IWI) TOO SMALL'
        WRITE(6,*)
        CALL EXIT(1)
      ELSEIF (IERR.LT.-5) THEN
        WRITE(6,*) 'ERROR - SDSREAD ERROR NUMBER ',IERR
        WRITE(6,*)
        CALL EXIT(1)
      ENDIF
      RETURN
      END
