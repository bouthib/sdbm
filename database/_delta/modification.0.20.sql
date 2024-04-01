-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 0  -   B e t a   --
---------------------------------------------
---------------------------------------------



#
# Modification du Firewall Linux (iptables)
#

vi /etc/sysconfig/iptables

# Ajout des lignes suivantes
---
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 22   -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 443  -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 1521 -j ACCEPT
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
---

service iptables restart



#
# Modification des fichiers de configuration réseau Linux
#

vi /etc/sysconfig/network-scripts/ifcfg-eth0 (remplacement du contenu du fichier)

---
# Advanced Micro Devices [AMD] 79c970 [PCnet32 LANCE]
DEVICE=eth0
ONBOOT=yes

# DHCP configuration
BOOTPROTO=dhcp

# FIXED configuration
#BOOTPROTO=none
#IPADDR=192.168.0.1
#NETWORK=192.168.0.0
#GATEWAY=192.168.0.254
#NETMASK=255.255.255.0
---

service network restart



#
# Modification du controleur SCSI BusLogic -> LSI Logic
#

* voir : Fedora10 - BUSLOGIC à LSI.txt



#
# Modification SDBM
#

ALTER TABLE PARAMETRE
   ADD ADRESSE_PROXY_HTTP VARCHAR2(100);


CREATE TABLE CD_INFO_STATIQUE_AGT
(
   DH_COLLECTE_DONNEE  DATE
  ,NOM_SERVEUR         VARCHAR2(64)
  ,SYS_UPTIME          NUMBER
  ,SYS_ARCH            VARCHAR2(50)
  ,SYS_VENDOR          VARCHAR2(50)
  ,SYS_DESCRIPTION     VARCHAR2(50)
  ,SYS_VENDOR_NAME     VARCHAR2(50)
  ,SYS_VENDOR_VERSION  VARCHAR2(50)
  ,SYS_VERSION         VARCHAR2(50)
  ,SYS_PATCH_LEVEL     VARCHAR2(50)
  ,SYS_NB_CORE         NUMBER
  ,HAR_CPU_VENDOR      VARCHAR2(50)
  ,HAR_CPU_MODEL       VARCHAR2(50)
  ,HAR_CPU_CLOCK_MHZ   NUMBER
  ,HAR_RAM_SIZE        NUMBER
  ,COMMENTAIRE         VARCHAR2(4000)
)
TABLESPACE SDBM_DATA
MONITORING;

ALTER TABLE CD_INFO_STATIQUE_AGT
   ADD CONSTRAINT ISA_PK_INFO_STATIQUE_AGT PRIMARY KEY (NOM_SERVEUR)
      USING INDEX
      TABLESPACE SDBM_DATA;



CREATE OR REPLACE VIEW SDBM.APEX_INFO_AGENT
AS 
   SELECT DH_COLLECTE_DONNEE        "DH_COLLECTE_DONNEE"
         ,NOM_SERVEUR               "NOM_SERVEUR"
         ,TRUNC(SYS_UPTIME / 86400) "SYS_UPTIME"
         ,SYS_ARCH
         ,SYS_VENDOR
         ,SYS_DESCRIPTION
         ,SYS_VENDOR_NAME
         ,SYS_VENDOR_VERSION
         ,SYS_VERSION
         ,SYS_PATCH_LEVEL
         ,SYS_NB_CORE
         ,HAR_CPU_VENDOR
         ,HAR_CPU_MODEL
         ,HAR_CPU_CLOCK_MHZ
         ,HAR_RAM_SIZE
         ,COMMENTAIRE
     FROM CD_INFO_STATIQUE_AGT;



ALTER TABLE CD_DBA_DATA_FILES
   DROP CONSTRAINT CDDDF_PK_CD_DBA_DATA_FILES;
   
ALTER TABLE CD_DBA_DATA_FILES
   DROP CONSTRAINT CDDDF_UK_CD_DBA_DATA_FILES;
   
DROP INDEX CDDDF_IE_NOM_CIB_FILE_ID_NAME;


RENAME CD_DBA_DATA_FILES TO CD_DBA_DATA_FILES_OLD;

CREATE TABLE CD_DBA_DATA_FILES
(
   DH_COLLECTE_DONNEE  DATE
  ,NOM_CIBLE           VARCHAR2(30)
  ,FILE_NAME           VARCHAR2(513)
  ,FILE_ID             NUMBER
  ,TABLESPACE_NAME     VARCHAR2(30)
  ,BYTES               NUMBER
  ,BYTES_FREE          NUMBER
  ,ID_VOLUME_PHY       NUMBER(6)        DEFAULT 0        NOT NULL
)   
TABLESPACE SDBM_DATA
MONITORING;

INSERT INTO CD_DBA_DATA_FILES
   SELECT DH_COLLECTE_DONNEE
         ,NOM_CIBLE
         ,FILE_NAME
         ,FILE_ID
         ,TABLESPACE_NAME
         ,BYTES
         ,NULL
         ,ID_VOLUME_PHY
     FROM CD_DBA_DATA_FILES_OLD;

DROP TABLE CD_DBA_DATA_FILES_OLD PURGE;


ALTER TABLE CD_DBA_DATA_FILES
   ADD CONSTRAINT CDDDF_PK_CD_DBA_DATA_FILES PRIMARY KEY (DH_COLLECTE_DONNEE, NOM_CIBLE, FILE_NAME)
      USING INDEX
      TABLESPACE SDBM_DATA;

ALTER TABLE CD_DBA_DATA_FILES
   ADD CONSTRAINT CDDDF_UK_CD_DBA_DATA_FILES UNIQUE (DH_COLLECTE_DONNEE, NOM_CIBLE, FILE_ID)
      USING INDEX
      TABLESPACE SDBM_DATA;

CREATE INDEX CDDDF_IE_NOM_CIB_FILE_ID_NAME ON CD_DBA_DATA_FILES (NOM_CIBLE, FILE_ID, FILE_NAME)
   TABLESPACE SDBM_DATA;


CREATE OR REPLACE TRIGGER SDBM.CDDDF_TR_ID_VOLUME_PHY

/******************************************************************
  TRIGGER : CDDDF_TR_ID_VOLUME_PHY
  AUTEUR  : Benoit Bouthillier 2009-02-18
 ------------------------------------------------------------------
  BUT : Recherche du ID_VOLUME_PHYSIQUE.

*******************************************************************/

   BEFORE INSERT OR UPDATE
   ON CD_DBA_DATA_FILES
   FOR EACH ROW

BEGIN

   SELECT ID_VOLUME_PHY
     INTO :NEW.ID_VOLUME_PHY
     FROM VOLUME_PHY_CIBLE
    WHERE TYPE_CIBLE        = 'BD'
      AND :NEW.NOM_CIBLE    = NOM_CIBLE
      AND :NEW.FILE_NAME LIKE CHEMIN_ACCES || '%'
      AND ROWNUM           <= 1;
      

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;

END CDDDF_TR_ID_VOLUME_PHY;
/

UPDATE SDBM.EVENEMENT
   SET COMMANDE = '
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,DBA_DATA_FILES.FILE_NAME
      ,DBA_DATA_FILES.FILE_ID
      ,DBA_DATA_FILES.TABLESPACE_NAME
      ,DBA_DATA_FILES.BYTES
      ,DECODE(DBA_TABLESPACES.CONTENTS
             ,''UNDO'',0
             ,(SELECT SUM(BYTES)
                 FROM DBA_FREE_SPACE@{DB_LINK}
                WHERE FILE_ID = DBA_DATA_FILES.FILE_ID
              )
             )
      ,0
  FROM DBA_DATA_FILES@{DB_LINK}
      ,DBA_TABLESPACES@{DB_LINK}
 WHERE DBA_DATA_FILES.TABLESPACE_NAME = DBA_TABLESPACES.TABLESPACE_NAME
UNION ALL
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,FILE_NAME
      ,FILE_ID + 10000
      ,TABLESPACE_NAME
      ,BYTES
      ,0
      ,0
  FROM DBA_TEMP_FILES@{DB_LINK}
'
 WHERE TYPE_CIBLE     = 'BD'
   AND NOM_EVENEMENT  = 'CD_DBA_DATA_FILES'
   AND TYPE_EVENEMENT = 'CD';



DROP MATERIALIZED VIEW MV_INFO_VOLUME_UTILISATION;
CREATE MATERIALIZED VIEW MV_INFO_VOLUME_UTILISATION
   REFRESH COMPLETE
   AS SELECT VLP.ID_VOLUME_PHY                                                                           ID_VOLUME_PHY
            ,VOL.NOM_CIBLE                                                                               NOM_CIBLE
            ,ROUND((AUJ.BYTES_FIC - HIE.BYTES_FIC) / 1024 / 1024 /   1,1)                                TAUX_CR_FIC_DERN_JOUR
            ,ROUND((AUJ.BYTES_FIC - SEM.BYTES_FIC) / 1024 / 1024 /   7,1)                                TAUX_CR_FIC_DERN_SEMAINE
            ,ROUND((AUJ.BYTES_FIC - MO1.BYTES_FIC) / 1024 / 1024 /  30,1)                                TAUX_CR_FIC_DERN_30_JRS
            ,ROUND((AUJ.BYTES_FIC - MO3.BYTES_FIC) / 1024 / 1024 /  90,1)                                TAUX_CR_FIC_DERN_90_JRS
            ,ROUND((AUJ.BYTES_FIC - ANN.BYTES_FIC) / 1024 / 1024 / 365,1)                                TAUX_CR_FIC_DERN_365_JRS
            ,NVL(ROUND(AUJ.BYTES_FIC / 1024 / 1024,1),0)                                                 TAILLE_FIC_UTILISE
            ,ROUND((AUJ.BYTES_OBJ - HIE.BYTES_OBJ) / 1024 / 1024 /   1,1)                                TAUX_CR_OBJ_DERN_JOUR
            ,ROUND((AUJ.BYTES_OBJ - SEM.BYTES_OBJ) / 1024 / 1024 /   7,1)                                TAUX_CR_OBJ_DERN_SEMAINE
            ,ROUND((AUJ.BYTES_OBJ - MO1.BYTES_OBJ) / 1024 / 1024 /  30,1)                                TAUX_CR_OBJ_DERN_30_JRS
            ,ROUND((AUJ.BYTES_OBJ - MO3.BYTES_OBJ) / 1024 / 1024 /  90,1)                                TAUX_CR_OBJ_DERN_90_JRS
            ,ROUND((AUJ.BYTES_OBJ - ANN.BYTES_OBJ) / 1024 / 1024 / 365,1)                                TAUX_CR_OBJ_DERN_365_JRS
            ,NVL(ROUND(AUJ.BYTES_OBJ / 1024 / 1024,1),0)                                                 TAILLE_OBJ_UTILISE
        FROM VOLUME_PHY
             VLP
            ,(
                SELECT ID_VOLUME_PHY ID_VOLUME_PHY
                      ,NOM_CIBLE     NOM_CIBLE
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE > TRUNC(SYSDATE) - 365
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             VOL
            ,(
                SELECT ID_VOLUME_PHY           ID_VOLUME_PHY
                      ,NOM_CIBLE               NOM_CIBLE
                      ,SUM(BYTES)              BYTES_FIC
                      ,SUM(BYTES - BYTES_FREE) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 0
                                              AND TRUNC(SYSDATE) - 0 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             AUJ
            ,(
                SELECT ID_VOLUME_PHY           ID_VOLUME_PHY
                      ,NOM_CIBLE               NOM_CIBLE
                      ,SUM(BYTES)              BYTES_FIC
                      ,SUM(BYTES - BYTES_FREE) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 1
                                              AND TRUNC(SYSDATE) - 1 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             HIE
            ,(
                SELECT ID_VOLUME_PHY           ID_VOLUME_PHY
                      ,NOM_CIBLE               NOM_CIBLE
                      ,SUM(BYTES)              BYTES_FIC
                      ,SUM(BYTES - BYTES_FREE) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 7
                                              AND TRUNC(SYSDATE) - 7 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             SEM
            ,(
                SELECT ID_VOLUME_PHY           ID_VOLUME_PHY
                      ,NOM_CIBLE               NOM_CIBLE
                      ,SUM(BYTES)              BYTES_FIC
                      ,SUM(BYTES - BYTES_FREE) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 30
                                              AND TRUNC(SYSDATE) - 30 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             MO1
            ,(
                SELECT ID_VOLUME_PHY           ID_VOLUME_PHY
                      ,NOM_CIBLE               NOM_CIBLE
                      ,SUM(BYTES)              BYTES_FIC
                      ,SUM(BYTES - BYTES_FREE) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 90
                                              AND TRUNC(SYSDATE) - 90 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             MO3
            ,(
                SELECT ID_VOLUME_PHY           ID_VOLUME_PHY
                      ,NOM_CIBLE               NOM_CIBLE
                      ,SUM(BYTES)              BYTES_FIC
                      ,SUM(BYTES - BYTES_FREE) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 365
                                              AND TRUNC(SYSDATE) - 365 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             ANN
       WHERE VOL.ID_VOLUME_PHY      = VLP.ID_VOLUME_PHY
         AND VOL.ID_VOLUME_PHY      = AUJ.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = AUJ.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = HIE.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = HIE.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = SEM.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = SEM.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = MO1.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = MO1.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = MO3.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = MO3.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = ANN.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = ANN.NOM_CIBLE(+);


DROP VIEW SDBM.APEX_TAB_EVOLUTION_BD;


CREATE OR REPLACE VIEW SDBM.APEX_TAB_EVOLUTION_FIC_BD
AS 
   SELECT NOM_CIBLE
         ,ID_VOLUME_PHY
         ,VOLUME
         ,COMMENTAIRE
         ,DERN_JOUR
         ,DERN_SEMAINE
         ,DERN_30_JRS
         ,DERN_90_JRS
         ,DERN_365_JRS
         ,ESPACE_UTIL_GB
         ,ESPACE_UTIL_VOL_GB
         ,ESPACE_DISP_VOL_GB
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN 'N/A - Regression'
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
             END
          NB_JOUR_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN 'N/A - Regression'
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_WC
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
             END
          NB_JOUR_WC
     FROM (
            SELECT INVU.NOM_CIBLE                                                                           NOM_CIBLE
                  ,INVU.ID_VOLUME_PHY                                                                       ID_VOLUME_PHY
                  ,VOLP.DESC_VOLUME_PHY                                                                     VOLUME
                  ,VOLP.COMMENTAIRE                                                                         COMMENTAIRE
                   /* Long term scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(CASE
                                         WHEN TAUX_CR_FIC_DERN_365_JRS IS NOT NULL THEN TAUX_CR_FIC_DERN_365_JRS
                                         WHEN TAUX_CR_FIC_DERN_90_JRS  IS NOT NULL THEN TAUX_CR_FIC_DERN_90_JRS
                                         WHEN TAUX_CR_FIC_DERN_30_JRS  IS NOT NULL THEN TAUX_CR_FIC_DERN_30_JRS
                                         WHEN TAUX_CR_FIC_DERN_SEMAINE IS NOT NULL THEN TAUX_CR_FIC_DERN_SEMAINE
                                         WHEN TAUX_CR_FIC_DERN_JOUR    IS NOT NULL THEN TAUX_CR_FIC_DERN_JOUR
                                      END
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_LT
                   /* Worst case scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(GREATEST(NVL(TAUX_CR_FIC_DERN_365_JRS,0)
                                              ,NVL(TAUX_CR_FIC_DERN_90_JRS,0)
                                              ,NVL(TAUX_CR_FIC_DERN_30_JRS,0)
                                              ,NVL(TAUX_CR_FIC_DERN_SEMAINE,0)
                                              )
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY  = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_WC
                  ,INVU.TAUX_CR_FIC_DERN_JOUR                                                               DERN_JOUR
                  ,INVU.TAUX_CR_FIC_DERN_SEMAINE                                                            DERN_SEMAINE
                  ,INVU.TAUX_CR_FIC_DERN_30_JRS                                                             DERN_30_JRS
                  ,INVU.TAUX_CR_FIC_DERN_90_JRS                                                             DERN_90_JRS
                  ,INVU.TAUX_CR_FIC_DERN_365_JRS                                                            DERN_365_JRS
                  ,ROUND(INVU.TAILLE_FIC_UTILISE / 1024,3)                                                  ESPACE_UTIL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT ROUND(SUM(TAILLE_FIC_UTILISE) / 1024,3)
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )                                                                                  ESPACE_UTIL_VOL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,ROUND(VOLP.TOTAL_MB / 1024,3)
                         )                                                                                  ESPACE_DISP_VOL_GB
              FROM MV_INFO_VOLUME_UTILISATION INVU
                  ,VOLUME_PHY                 VOLP
             WHERE INVU.ID_VOLUME_PHY = VOLP.ID_VOLUME_PHY
          );


CREATE OR REPLACE VIEW SDBM.APEX_TAB_EVOLUTION_OBJ_BD
AS 
   SELECT NOM_CIBLE
         ,ID_VOLUME_PHY
         ,VOLUME
         ,COMMENTAIRE
         ,DERN_JOUR
         ,DERN_SEMAINE
         ,DERN_30_JRS
         ,DERN_90_JRS
         ,DERN_365_JRS
         ,ESPACE_UTIL_GB
         ,ESPACE_UTIL_VOL_GB
         ,ESPACE_DISP_VOL_GB
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN 'N/A - Regression'
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
             END
          NB_JOUR_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN 'N/A - Regression'
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_WC
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
             END
          NB_JOUR_WC
     FROM (
            SELECT INVU.NOM_CIBLE                                                                           NOM_CIBLE
                  ,INVU.ID_VOLUME_PHY                                                                       ID_VOLUME_PHY
                  ,VOLP.DESC_VOLUME_PHY                                                                     VOLUME
                  ,VOLP.COMMENTAIRE                                                                         COMMENTAIRE
                   /* Long term scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(CASE
                                         WHEN TAUX_CR_OBJ_DERN_365_JRS IS NOT NULL THEN TAUX_CR_OBJ_DERN_365_JRS
                                         WHEN TAUX_CR_OBJ_DERN_90_JRS  IS NOT NULL THEN TAUX_CR_OBJ_DERN_90_JRS
                                         WHEN TAUX_CR_OBJ_DERN_30_JRS  IS NOT NULL THEN TAUX_CR_OBJ_DERN_30_JRS
                                         WHEN TAUX_CR_OBJ_DERN_SEMAINE IS NOT NULL THEN TAUX_CR_OBJ_DERN_SEMAINE
                                         WHEN TAUX_CR_OBJ_DERN_JOUR    IS NOT NULL THEN TAUX_CR_OBJ_DERN_JOUR
                                      END
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_LT
                   /* Worst case scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(GREATEST(NVL(TAUX_CR_OBJ_DERN_365_JRS,0)
                                              ,NVL(TAUX_CR_OBJ_DERN_90_JRS,0)
                                              ,NVL(TAUX_CR_OBJ_DERN_30_JRS,0)
                                              ,NVL(TAUX_CR_OBJ_DERN_SEMAINE,0)
                                              )
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_WC
                  ,INVU.TAUX_CR_OBJ_DERN_JOUR                                                               DERN_JOUR
                  ,INVU.TAUX_CR_OBJ_DERN_SEMAINE                                                            DERN_SEMAINE
                  ,INVU.TAUX_CR_OBJ_DERN_30_JRS                                                             DERN_30_JRS
                  ,INVU.TAUX_CR_OBJ_DERN_90_JRS                                                             DERN_90_JRS
                  ,INVU.TAUX_CR_OBJ_DERN_365_JRS                                                            DERN_365_JRS
                  ,ROUND(INVU.TAILLE_OBJ_UTILISE / 1024,3)                                                  ESPACE_UTIL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT ROUND(SUM(TAILLE_OBJ_UTILISE) / 1024,3)
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )                                                                                  ESPACE_UTIL_VOL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,ROUND(VOLP.TOTAL_MB / 1024,3)
                         )                                                                                  ESPACE_DISP_VOL_GB
              FROM MV_INFO_VOLUME_UTILISATION INVU
                  ,VOLUME_PHY                 VOLP
             WHERE INVU.ID_VOLUME_PHY = VOLP.ID_VOLUME_PHY
          );



@../_package/ps-sdbm_agent.sql
@../_package/pb-sdbm_agent.sql



SDBMAgt version 0.07 - Beta
---------------------------

InstallSDBMAgt.cmd
sdbmagtctl
SDBMAgt.jar
sigar\*.*



SDBM - Application Oracle APEX
------------------------------

@../_package/ps-apex_show_hide_memory.sql
@../_package/pb-apex_show_hide_memory.sql
@../_apex/sdbm_apex_f101.release.0.20.sql
@../_apex/sdbm_apex_f101.static_file.sql
