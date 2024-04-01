-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 1 7  -   B e t a   --
---------------------------------------------
---------------------------------------------



ALTER TABLE PARAMETRE DROP CONSTRAINT PAR_CHK_GARANTIE_NOTIF_SERVEUR;
ALTER TABLE PARAMETRE DROP CONSTRAINT PAR_PK_PARAMETRE_NOTIF_EXT;

RENAME PARAMETRE TO PARAMETRE_OLD;

CREATE TABLE PARAMETRE
(
   CLE                            NUMBER(1)       NOT NULL
  ,STATUT_SERVEUR                 CHAR(2)         NOT NULL
  ,FREQU_VERIF_CIBLE_SEC          NUMBER(4)       NOT NULL
  ,DELAI_MAX_CONNEXION_SEC        NUMBER(3)       NOT NULL
  ,DELAI_EPURATION_JOURNAL        NUMBER(3)       NOT NULL
  ,NIVEAU_JOURNAL_SERVEUR         VARCHAR2(30)    NOT NULL
  ,GARANTIE_NOTIF_SERVEUR         CHAR(2)         NOT NULL
  ,LIMITE_NOTIF_CYCLE_SERVEUR     NUMBER(4)       NOT NULL
  ,STATUT_AGENT                   CHAR(2)         NOT NULL
  ,FREQU_VERIF_AGENT              NUMBER(4)       NOT NULL
  ,FREQU_VERIF_AGENT_TACHE        NUMBER(4)       NOT NULL
  ,DELAI_EPURATION_LOG_BD_TACHE   NUMBER(3)       NOT NULL
  ,DELAI_EPURATION_LOG_FIC_TACHE  NUMBER(3)       NOT NULL
  ,LIMITE_NOTIF_CYCLE_AGENT       NUMBER(4)       NOT NULL
  ,DELAI_EPURATION_COLLECTE       NUMBER(4)       NOT NULL
  ,STATUT_COLLECTE                CHAR(2)         NOT NULL
  ,DELAI_AJUSTEMENT_DST_SEC       NUMBER(4)       NOT NULL
  ,FUSEAU_HOR_DERN_EXEC           NUMBER(2)
  ,SERVEUR_SMTP                   VARCHAR2(50)
  ,PORT_SMTP                      NUMBER(5)       NOT NULL
  ,NOM_USAGER_SMTP                VARCHAR2(30)
  ,MDP_USAGER_SMTP                VARCHAR2(32)
  ,EXPEDITEUR_SMTP                VARCHAR2(100)
)   
TABLESPACE SDBM_DATA
MONITORING;

INSERT INTO PARAMETRE
   SELECT CLE
         ,STATUT_SERVEUR
         ,FREQU_VERIF_CIBLE_SEC
         ,DELAI_MAX_CONNEXION_SEC
         ,DELAI_EPURATION_JOURNAL
         ,NIVEAU_JOURNAL_SERVEUR
         ,GARANTIE_NOTIF_SERVEUR
         ,LIMITE_NOTIF_CYCLE_SERVEUR
         ,STATUT_AGENT
         ,FREQU_VERIF_AGENT
         ,10
         ,7
         ,7
         ,LIMITE_NOTIF_CYCLE_AGENT
         ,DELAI_EPURATION_COLLECTE
         ,STATUT_COLLECTE
         ,DELAI_AJUSTEMENT_DST_SEC
         ,FUSEAU_HOR_DERN_EXEC
         ,SERVEUR_SMTP
         ,PORT_SMTP
         ,NOM_USAGER_SMTP
         ,MDP_USAGER_SMTP
         ,EXPEDITEUR_SMTP
     FROM PARAMETRE_OLD;
     
DROP TABLE PARAMETRE_OLD PURGE;


ALTER TABLE PARAMETRE
   ADD CONSTRAINT PAR_CHK_GARANTIE_NOTIF_SERVEUR
      CHECK (GARANTIE_NOTIF_SERVEUR IN (/* Complète */ 'CO',/* Partielle */ 'PA',/* Aucune */ 'AU'));


ALTER TABLE PARAMETRE
   ADD CONSTRAINT PAR_PK_PARAMETRE_NOTIF_EXT PRIMARY KEY (CLE)
      USING INDEX
      TABLESPACE SDBM_DATA;



CREATE TABLE INFO_AGT
(
   NOM_SERVEUR          VARCHAR2(64)                        NOT NULL
  ,NOM_OS               VARCHAR2(50)                        NOT NULL
  ,USAGER_EXECUTION     VARCHAR2(256)                       NOT NULL
  ,STATUT_TACHE         CHAR(2)                             NOT NULL
)
TABLESPACE SDBM_DATA
MONITORING;


ALTER TABLE INFO_AGT
   ADD CONSTRAINT IAG_PK_INFO_AGT PRIMARY KEY (NOM_SERVEUR)
      USING INDEX
      TABLESPACE SDBM_DATA;



CREATE TABLE INFO_DET_INT_AGT
(
   NOM_SERVEUR          VARCHAR2(64)                        NOT NULL
  ,INTERPRETEUR         VARCHAR2(50)                        NOT NULL
)
TABLESPACE SDBM_DATA
MONITORING;


ALTER TABLE INFO_DET_INT_AGT
   ADD CONSTRAINT IDIG_PK_INFO_DET_INT_AGT PRIMARY KEY (NOM_SERVEUR, INTERPRETEUR)
      USING INDEX
      TABLESPACE SDBM_DATA;



CREATE TABLE TACHE_AGT
(
   NOM_SERVEUR          VARCHAR2(64)                        NOT NULL
  ,NOM_TACHE            VARCHAR2(50)                        NOT NULL
  ,EXECUTABLE           VARCHAR2(256)                       NOT NULL
  ,PARAMETRE            VARCHAR2(1024)                      NOT NULL
  ,REPERTOIRE           VARCHAR2(256)                       NOT NULL
  ,REPERTOIRE_JOURNAL   VARCHAR2(256)                       NOT NULL
  ,EXECUTION            CHAR(2)         DEFAULT 'AC'        NOT NULL
  ,TYPE_NOTIF           CHAR(2)         DEFAULT 'OF'        NOT NULL
  ,DESTI_NOTIF          VARCHAR2(30)                        NOT NULL
  ,INTERVAL             VARCHAR2(500)                       NOT NULL
  ,DELAI_AVERTISSEMENT  NUMBER(4)                           NOT NULL
  ,DH_PROCHAINE_EXEC    DATE            DEFAULT SYSDATE     NOT NULL
  ,CODE_RETOUR_SUCCES   VARCHAR2(100)   DEFAULT '{RC} = 0'  NOT NULL
  ,COMMENTAIRE          VARCHAR2(4000)
)
TABLESPACE SDBM_DATA
MONITORING;


ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_CHK_EXECUTION
      CHECK (EXECUTION IN (/* Actif */ 'AC',/* Inactif */ 'IN'));

ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_CHK_TYPE_NOTIF
      CHECK (TYPE_NOTIF IN (/* Sur erreur */ 'OF', /* Toujours */ 'AL'));


ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_PK_TACHE_AGT PRIMARY KEY (NOM_SERVEUR, NOM_TACHE)
      USING INDEX
      TABLESPACE SDBM_DATA;



CREATE TABLE TACHE_DET_MSG_AGT
(
   NOM_SERVEUR          VARCHAR2(64)                        NOT NULL
  ,NOM_TACHE            VARCHAR2(50)                        NOT NULL
  ,TYPE_MSG             CHAR(2)         DEFAULT 'OK'        NOT NULL
  ,MSG                  VARCHAR2(512)                       NOT NULL
  ,COMMENTAIRE          VARCHAR2(4000)
)
TABLESPACE SDBM_DATA
MONITORING;


ALTER TABLE TACHE_DET_MSG_AGT
   ADD CONSTRAINT TDMA_CHK_TYPE_MESSAGE
      CHECK (TYPE_MSG IN (/* Massage à trouver */ 'OK', /* Message à ne pas trouver */ 'ER'));


CREATE INDEX TDMA_FK_TACHE_AGT ON TACHE_DET_MSG_AGT (NOM_SERVEUR, NOM_TACHE)
   TABLESPACE SDBM_DATA;



CREATE TABLE HIST_TACHE_AGT
(
   ID_SOUMISSION        NUMBER(10)                          NOT NULL
  ,NOM_SERVEUR          VARCHAR2(64)                        NOT NULL
  ,NOM_TACHE            VARCHAR2(50)                        NOT NULL
  ,FICHIER_JOURNAL      VARCHAR2(256)                       NOT NULL
  ,STATUT_EXEC          CHAR(2)                             NOT NULL
  ,STATUT_NOTIF_AVER    CHAR(2)         DEFAULT 'NO'        NOT NULL
  ,STATUT_NOTIF_EXEC    CHAR(2)         DEFAULT 'NO'        NOT NULL
  ,DH_SOUMISSION        DATE                                NOT NULL
  ,DH_DEBUT             DATE
  ,DH_FIN               DATE
  ,CODE_RETOUR          NUMBER
  ,JOURNAL              CLOB
  ,EVALUATION           VARCHAR2(512)
)
LOB (JOURNAL) STORE AS (DISABLE STORAGE IN ROW)
TABLESPACE SDBM_DATA
MONITORING;


ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_EXEC
      CHECK (STATUT_EXEC IN (/* Soumission */ 'SB',/* Soumission reçu */ 'SR',/* Erreur à la soumission */ 'SF',/* Exécution */ 'EX',/* Incomplet */ 'NC',/* Évaluation */ 'EV',/* Fin en erreur */ 'ER',/* Fin avec succès */ 'OK'));

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_NOTIF_AVER
      CHECK (STATUT_NOTIF_AVER IN (/* Normal */ 'NO',/* À notifier */ 'AE',/* Final */ 'OK'));

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_NOTIF_EXEC
      CHECK (STATUT_NOTIF_EXEC IN (/* Normal */ 'NO',/* À notifier */ 'AE',/* Final */ 'OK'));


CREATE INDEX HTA_IE_NOM_SERVEUR_NOM_TACHE ON HIST_TACHE_AGT (NOM_SERVEUR, NOM_TACHE)
   TABLESPACE SDBM_DATA;

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_PK_HIST_TACHE_AGT PRIMARY KEY (ID_SOUMISSION)
      USING INDEX
      TABLESPACE SDBM_DATA;



ALTER TABLE INFO_DET_INT_AGT
   ADD CONSTRAINT IDIG_FK_INFO_AGT
       FOREIGN KEY (NOM_SERVEUR) REFERENCES INFO_AGT
       ON DELETE CASCADE;

/* APEX : Modification de la validation de suppression d'une destination de modification */
ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_FK_DESTI_NOTIF
       FOREIGN KEY (DESTI_NOTIF) REFERENCES DESTI_NOTIF;

ALTER TABLE TACHE_DET_MSG_AGT
   ADD CONSTRAINT TDMA_FK_TACHE_AGT
       FOREIGN KEY (NOM_SERVEUR, NOM_TACHE) REFERENCES TACHE_AGT
       ON DELETE CASCADE;

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_FK_TACHE_AGT
       FOREIGN KEY (NOM_SERVEUR, NOM_TACHE) REFERENCES TACHE_AGT
       ON DELETE CASCADE;




CREATE SEQUENCE SDBM.HTA_ID_SOUMISSION
   MINVALUE 1
   MAXVALUE 9999999999
   CYCLE
   NOCACHE;


@../_package/ps-sdbm_agent.sql
@../_package/pb-sdbm_agent.sql

@../_package/ps-sdbm_apex_util.sql
@../_package/pb-sdbm_apex_util.sql

@../_package/pb-sdbm_util.sql


CREATE OR REPLACE VIEW SDBM.APEX_STATUT_SESSION_SDBM
AS 
   SELECT 'N/D'                                              "SERVEUR"
         ,'SDBMSRV - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
         ,'*** SDBMSrv is not running ***'                   "DESCRIPTION"
         ,'N/D'                                              "DERNIERE_ACTION"
         ,'N/D'                                              "ORACLE_LOGON"
         ,'N/D'                                              "ORACLE_SPID"
         ,'N/D'                                              "ORACLE_SID"
         ,'N/D'                                              "ORACLE_SERIAL"
         ,'N/D'                                              "ORACLE_STATUS"
         ,5                                                  "MISE_EN_EVIDENCE"
     FROM DUAL
    WHERE NOT EXISTS (SELECT 1
                        FROM V$SESSION
                       WHERE MODULE LIKE 'SDBMSRV - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                     )
   UNION ALL
   (
      SELECT UPPER(CIB.NOM_SERVEUR)                             "SERVEUR"
            ,'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
            ,'*** SDBMAgt is not running ***'                   "DESCRIPTION"
            ,'N/D'                                              "DERNIERE_ACTION"
            ,'N/D'                                              "ORACLE_LOGON"
            ,'N/D'                                              "ORACLE_SPID"
            ,'N/D'                                              "ORACLE_SID"
            ,'N/D'                                              "ORACLE_SERIAL"
            ,'N/D'                                              "ORACLE_STATUS"
            ,3                                                  "MISE_EN_EVIDENCE"
        FROM CIBLE           CIB
            ,EVENEMENT_CIBLE EVC
       WHERE CIB.TYPE_CIBLE    = EVC.TYPE_CIBLE
         AND CIB.NOM_CIBLE     = EVC.NOM_CIBLE
         AND CIB.NOTIFICATION  = 'AC'
         AND CIB.NOM_SERVEUR IS NOT NULL
         AND EVC.TYPE_CIBLE    = 'BD'
         AND EVC.NOM_EVENEMENT = 'ALERT'
         AND UPPER(CIB.NOM_SERVEUR) NOT IN (SELECT UPPER(SUBSTR(CLIENT_INFO,INSTR(CLIENT_INFO,'running on ') + 11)) "SERVEUR"
                                              FROM V$SESSION
                                             WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                           )
      UNION
      SELECT UPPER(NOM_SERVEUR)                             "SERVEUR"
            ,'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
            ,'*** SDBMAgt is not running ***'                   "DESCRIPTION"
            ,'N/D'                                              "DERNIERE_ACTION"
            ,'N/D'                                              "ORACLE_LOGON"
            ,'N/D'                                              "ORACLE_SPID"
            ,'N/D'                                              "ORACLE_SID"
            ,'N/D'                                              "ORACLE_SERIAL"
            ,'N/D'                                              "ORACLE_STATUS"
            ,3                                                  "MISE_EN_EVIDENCE"
        FROM TACHE_AGT
       WHERE EXECUTION = 'AC'
         AND NOM_SERVEUR NOT IN (SELECT UPPER(SUBSTR(CLIENT_INFO,INSTR(CLIENT_INFO,'running on ') + 11)) "SERVEUR"
                                   FROM V$SESSION
                                  WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                )
   )
   UNION ALL
   SELECT UPPER(SUBSTR(SESS.CLIENT_INFO,INSTR(SESS.CLIENT_INFO,'running on ') + 11)) "SERVEUR"
         ,SESS.MODULE                                                                "MODULE"
         ,SUBSTR(SESS.CLIENT_INFO,1,INSTR(SESS.CLIENT_INFO,' running on ')-1)        "DESCRIPTION"
         ,SESS.ACTION                                                                "DERNIERE_ACTION"
         ,TO_CHAR(SESS.LOGON_TIME,'YYYY/MM/DD:HH24:MI:SS')                           "ORACLE_LOGON"
         ,TO_CHAR(PROC.SPID)                                                         "ORACLE_SPID"
         ,TO_CHAR(SESS.SID)                                                          "ORACLE_SID"
         ,TO_CHAR(SESS.SERIAL#)                                                      "ORACLE_SERIAL"
         ,STATUS                                                                     "ORACLE_STATUS"
         ,DECODE(SUBSTR(SESS.MODULE,1,7)
                ,'SDBMSRV',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') > (SELECT (FREQU_VERIF_CIBLE_SEC + 60) / 86400 FROM PARAMETRE)) THEN 3 ELSE 1 END)
                ,'SDBMAGT',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') > (SELECT (FREQU_VERIF_AGENT     + 60) / 86400 FROM PARAMETRE)) THEN 3 ELSE 1 END)
                )                                                                    "MISE_EN_EVIDENCE"
     FROM V$SESSION SESS
         ,V$PROCESS PROC
    WHERE SESS.PADDR = PROC.ADDR
      AND SESS.MODULE LIKE 'SDBM___ - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA;


CREATE OR REPLACE VIEW SDBM.APEX_CIBLE_BD
AS 
   SELECT TO_CHAR(
                   DECODE(STATUT
                        ,'DN',5
                        ,DECODE(STATUT
                               ,'UK',5
                               ,DECODE(NB_EVENEMENT_OUVERT
                                      ,0,DECODE(NB_ALERT_OUVERT
                                               ,0,DECODE(NB_EVENEMENT_REPARATION
                                                        ,0,1
                                                        ,2
                                                        )
                                               ,3
                                               )
                                      ,4
                                      )
                               )
                         )
                 )                                                                                                            "SEVERITE"
         ,NOM_CIBLE
         ,NOM_SERVEUR
         ,INFORMATION_OS
         ,SGBD
         ,VERSION
         ,STATUT_AFF
         ,STATUT
         ,DH_STATUT
         ,NB_JOUR_STATUT
         ,DH_DERN_VERIF
         ,DH_PROCHAINE_VERIF
         ,NOTIFICATION_AFF
         ,NOTIFICATION
         ,NOTIFICATION_EN_ATTENTE
         ,STATUT_ALERT
         ,NB_ALERT_OUVERT
         ,STATUT_COLLECTE
         ,NB_EVENEMENT_OUVERT
     FROM (
            SELECT NOM_CIBLE                                                                                                  "NOM_CIBLE"
                  ,DECODE(INSTR(NOM_SERVEUR,'.')
                         ,0,UPPER(NOM_SERVEUR)
                         ,UPPER(SUBSTR(NOM_SERVEUR,1,INSTR(NOM_SERVEUR,'.')-1))
                         )                                                                                                    "NOM_SERVEUR"
                  ,(SELECT NOM_OS
                      FROM INFO_AGT
                     WHERE NOM_SERVEUR = UPPER(CIBLE.NOM_SERVEUR)
                   )                                                                                                          "INFORMATION_OS"
                  ,DECODE(SOUS_TYPE_CIBLE
                         ,'OR','Oracle'
                         ,'MS','SQLServer'
                         ,SOUS_TYPE_CIBLE
                         )                                                                                                    "SGBD"
                  ,DECODE(VERSION
                         ,TO_CHAR(NULL),'N/D'
                         ,SUBSTR(VERSION,INSTR(VERSION,':')+2)
                         )                                                                                                    "VERSION"
                  ,DECODE(STATUT
                         ,'UP','Disponible'
                         ,'DN','Non-disponible'
                         ,'Inconnu'
                         )                                                                                                    "STATUT_AFF"
                  ,STATUT                                                                                                     "STATUT"
                  ,TO_CHAR(DECODE(STATUT
                                 ,'UP',STARTUP_TIME
                                 ,DH_MAJ_STATUT
                                 )
                          ,'YYYY/MM/DD:HH24:MI:SS'
                          )                                                                                                   "DH_STATUT"
                  ,TO_CHAR(TRUNC(SYSDATE - DECODE(STATUT
                                                 ,'UP',STARTUP_TIME
                                                 ,DH_MAJ_STATUT
                                                 )
                                )
                          )                                                                                                   "NB_JOUR_STATUT"
                  ,NVL(TO_CHAR(DH_DERN_VERIF
                              ,'YYYY/MM/DD:HH24:MI:SS'
                              )
                      ,'N/D'
                      )                                                                                                       "DH_DERN_VERIF"
                  ,NVL(TO_CHAR(DH_PROCHAINE_VERIF
                              ,'YYYY/MM/DD:HH24:MI:SS'
                              )
                      ,'N/D'
                      )                                                                                                       "DH_PROCHAINE_VERIF"
                  ,DECODE(NOTIFICATION
                         ,'AC','Actif'
                         ,'IN','Inactif'
                         )                                                                                                    "NOTIFICATION_AFF"
                  ,NOTIFICATION                                                                                               "NOTIFICATION"
                  ,DECODE(NOTIF_EFFECT
                         ,'OK','Non'
                         ,'Oui'
                         )                                                                                                    "NOTIFICATION_EN_ATTENTE"
                  ,(SELECT DECODE(COUNT(1),0,'IN','AC')
                      FROM EVENEMENT_CIBLE
                     WHERE TYPE_CIBLE   = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE    = CIBLE.NOM_CIBLE
                       AND NOM_EVENEMENT = 'ALERT'
                   )                                                                                                          "STATUT_ALERT"
                  ,(SELECT TO_CHAR(COUNT(1))
                      FROM HIST_EVENEMENT_CIBLE_AGT
                     WHERE DH_HIST_EVENEMENT > SYSDATE - 1/24
                       AND TYPE_CIBLE        = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE         = CIBLE.NOM_CIBLE
                       AND TEXTE         NOT LIKE '%ORA-00000%'
                   )                                                                                                          "NB_ALERT_OUVERT"
                  ,(SELECT DECODE(COUNT(1),0,'IN','AC')
                      FROM EVENEMENT_CIBLE
                     WHERE TYPE_CIBLE   = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE    = CIBLE.NOM_CIBLE
                       AND NOM_EVENEMENT IN
                           (
                              'CD_DBA_DATA_FILES'
                             ,'CD_ESPACE_ARCHIVED_LOG'
                             ,'CD_FILESTAT'
                           )
                   )                                                                                                          "STATUT_COLLECTE"
                  ,(SELECT TO_CHAR(COUNT(1))
                      FROM HIST_EVENEMENT_CIBLE
                     WHERE TYPE_CIBLE   = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE    = CIBLE.NOM_CIBLE
                       AND DH_FERMETURE IS NULL
                   )                                                                                                          "NB_EVENEMENT_OUVERT"
                  ,GREATEST((
                              SELECT COUNT(1)
                                FROM HIST_EVENEMENT_CIBLE HEC
                                    ,EVENEMENT            EVE
                               WHERE HEC.TYPE_CIBLE       = CIBLE.TYPE_CIBLE
                                 AND HEC.NOM_CIBLE        = CIBLE.NOM_CIBLE
                                 AND EVE.TYPE_CIBLE       = CIBLE.TYPE_CIBLE
                                 AND EVE.SOUS_TYPE_CIBLE  = CIBLE.SOUS_TYPE_CIBLE
                                 AND EVE.NOM_EVENEMENT    = HEC.NOM_EVENEMENT
                                 AND HEC.DH_FERMETURE     > SYSDATE - 1/24
                                 AND EVE.TYPE_FERMETURE  != 'AU'
                            )
                           ,(
                              SELECT COUNT(1)
                                FROM DUAL
                               WHERE CIBLE.DH_MAJ_STATUT > SYSDATE - 1/24
                            )
                           )                                                                                                  "NB_EVENEMENT_REPARATION"
              FROM CIBLE
             WHERE TYPE_CIBLE = 'BD'
          );


CREATE OR REPLACE TRIGGER SDBM.APEX_CIBLE_BD_TRIOU_CIBLE
   INSTEAD OF UPDATE ON APEX_CIBLE_BD

BEGIN

   IF (:OLD.STATUT != :NEW.STATUT) THEN

      UPDATE CIBLE
         SET STATUT = :NEW.STATUT
       WHERE NOM_CIBLE = :NEW.NOM_CIBLE;

   END IF;
         
   IF (:OLD.NOTIFICATION != :NEW.NOTIFICATION) THEN

      UPDATE CIBLE
         SET NOTIFICATION = :NEW.NOTIFICATION
       WHERE NOM_CIBLE = :NEW.NOM_CIBLE;

   END IF;

END APEX_CIBLE_BD_TRIOU_CIBLE;
/


INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'DELAI_AVERTISSEMENT'
  ,'60'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'CODE_RETOUR_SUCCES'
  ,'{RC} = 0'
);



UPDATE SDBM.EVENEMENT
   SET COMMANDE = 
   '
SELECT ''N/A''
      ,DECODE(NB_ARCHIVED_LOG
             ,1,NB_ARCHIVED_LOG || '' "archived log" semble ne pas avoir été avoir été détruit (donc sauvegardé) dans RMAN depuis le '' || TO_CHAR(DEPUIS,''YYYY/MM/DD:HH24:MI:SS'') || ''.''
             ,NB_ARCHIVED_LOG || '' "archived logs" semblent ne pas avoir été avoir été détruits (donc sauvegardés) dans RMAN depuis le '' || TO_CHAR(DEPUIS,''YYYY/MM/DD:HH24:MI:SS'') || ''.''
             )
   FROM (
         SELECT COUNT(1)             "NB_ARCHIVED_LOG"
               ,MIN(COMPLETION_TIME) "DEPUIS"
           FROM V$ARCHIVED_LOG
          WHERE DELETED         = ''NO''
            AND STANDBY_DEST    = ''NO''
            AND COMPLETION_TIME < SYSDATE - 7
       )
 WHERE NB_ARCHIVED_LOG != 0
   AND EXISTS (SELECT 1
                 FROM V$DATABASE
                WHERE LOG_MODE != ''NOARCHIVELOG''
              ) 
'
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR'
   AND NOM_EVENEMENT   = 'RMAN_ARCHIVE';


BEGIN DBMS_JOB.INTERVAL(102,'TRUNC(SYSDATE) + 1 + 30/1440'); END;
COMMIT;



ALTER TABLE SDBM.EVENEMENT
   ADD (VISIBLE CHAR(2) DEFAULT 'AC' NOT NULL);

ALTER TABLE SDBM.EVENEMENT
   ADD CONSTRAINT EVE_CHK_VISIBLE
      CHECK (VISIBLE IN (/* Actif */ 'AC',/* Inactif */ 'IN'));
