-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 8  -   B e t a   --
---------------------------------------------
---------------------------------------------


#
# Mise à jour Apex 4.1
#
voir _Installation OS & Oracle XE/Upgrade APEX 4.1.txt


# Mise à jour Apex à 0.28b

ALTER SESSION SET CURRENT_SCHEMA = SDBM;

ALTER TABLE PARAMETRE DROP CONSTRAINT PAR_CHK_GARANTIE_NOTIF_SERVEUR;
ALTER TABLE PARAMETRE DROP CONSTRAINT PAR_PK_PARAMETRE_NOTIF_EXT;

ALTER TABLE PARAMETRE RENAME TO PARAMETRE_028;

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
  ,RETARD_MAX_SOUMISSION_TACHE    NUMBER(5)       NOT NULL
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
  ,ADRESSE_PROXY_HTTP             VARCHAR2(100)
  ,LANGUE                         CHAR(2)         NOT NULL
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
         ,FREQU_VERIF_AGENT_TACHE
         ,120
         ,DELAI_EPURATION_LOG_BD_TACHE
         ,DELAI_EPURATION_LOG_FIC_TACHE
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
         ,ADRESSE_PROXY_HTTP
         ,LANGUE
     FROM PARAMETRE_028;
     
DROP TABLE PARAMETRE_028 PURGE;


ALTER TABLE PARAMETRE
   ADD CONSTRAINT PAR_CHK_GARANTIE_NOTIF_SERVEUR
      CHECK (GARANTIE_NOTIF_SERVEUR IN (/* Complète */ 'CO',/* Partielle */ 'PA',/* Aucune */ 'AU'));


ALTER TABLE PARAMETRE
   ADD CONSTRAINT PAR_PK_PARAMETRE_NOTIF_EXT PRIMARY KEY (CLE)
      USING INDEX
      TABLESPACE SDBM_DATA;


DROP TRIGGER SDBM.PAR_TR_BIUD_PAR_NOTIF_EXT;
CREATE OR REPLACE TRIGGER SDBM.PAR_TR_BIUD_PAR_NOTIF_EXT

/******************************************************************
  TRIGGER : PAR_TR_BIUD_PAR_NOTIF_EXT
  AUTEUR  : Benoit Bouthillier 2009-01-05
 ------------------------------------------------------------------
  BUT : Effectue le maintient de l'enregistrement SMTP de la table
        PARAMETRE_NOTIF_EXT.

*******************************************************************/

   BEFORE INSERT OR UPDATE OR DELETE
   ON PARAMETRE
   FOR EACH ROW

BEGIN

   IF (INSERTING) THEN

      DELETE FROM PARAMETRE_NOTIF_EXT
         WHERE TYPE_NOTIF = 'SMTP';

      INSERT INTO PARAMETRE_NOTIF_EXT
      (
         TYPE_NOTIF
        ,SIGNATURE_FONCTION
        ,COMMENTAIRE
      )
      VALUES
      (
         'SMTP'
        ,'NULL'
        ,'This record should not be altered'
      );

   ELSIF (UPDATING('SERVEUR_SMTP')) THEN
   
      IF (:OLD.SERVEUR_SMTP IS NULL AND :NEW.SERVEUR_SMTP IS NOT NULL) THEN
   
         INSERT INTO PARAMETRE_NOTIF_EXT
    (
       TYPE_NOTIF
      ,SIGNATURE_FONCTION
      ,COMMENTAIRE
    )
    VALUES
    (
       'SMTP'
      ,'NULL'
      ,'This record should not be altered'
    );
 
      ELSIF (:NEW.SERVEUR_SMTP IS NULL AND :OLD.SERVEUR_SMTP IS NOT NULL) THEN

         DELETE FROM PARAMETRE_NOTIF_EXT
            WHERE TYPE_NOTIF = 'SMTP';

      END IF;

   ELSIF (DELETING) THEN

      DELETE FROM PARAMETRE_NOTIF_EXT
         WHERE TYPE_NOTIF = 'SMTP';
   
   END IF;

END;
/


CREATE OR REPLACE VIEW SDBM.APEX_STATUT_SESSION_SDBM
AS 
  SELECT 'N/D'                                               "SERVEUR"
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
      SELECT UPPER(NOM_SERVEUR)                                 "SERVEUR"
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
         ,DECODE(SUBSTR(SESS.MODULE,1,7)
                ,'SDBMSRV',SESS.ACTION || ' (' || NVL(CLIENT_IDENTIFIER,'--') || ')'
                ,SESS.ACTION
                )                                                                    "DERNIERE_ACTION"
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



ALTER TABLE DESTI_NOTIF_DETAIL
   DROP CONSTRAINT DND_FK_DESTI_NOTIF;

ALTER TABLE DESTI_NOTIF_DETAIL
   DROP CONSTRAINT DND_FK_TYPE_NOTIF;

ALTER TABLE DESTI_NOTIF_DETAIL DROP CONSTRAINT DND_CHK_RETRAIT_ACCENT;
ALTER TABLE DESTI_NOTIF_DETAIL DROP CONSTRAINT DND_CHK_SUPPORT_FICHIER;
ALTER TABLE DESTI_NOTIF_DETAIL DROP CONSTRAINT DND_PK_DESTI_NOTIF;

ALTER TABLE DESTI_NOTIF_DETAIL RENAME TO DESTI_NOTIF_DETAIL_028;

CREATE TABLE DESTI_NOTIF_DETAIL
(
   DESTI_NOTIF          VARCHAR2(30)                     NOT NULL
  ,TYPE_NOTIF           VARCHAR2(30)    DEFAULT 'SMTP'   NOT NULL
  ,ADRESSE              VARCHAR2(100)                    NOT NULL
  ,RETRAIT_ACCENT       CHAR(2)         DEFAULT 'FA'     NOT NULL
  ,SUPPORT_FICHIER      CHAR(2)         DEFAULT 'VR'     NOT NULL
  ,SQL_HORAIRE          VARCHAR2(500)   DEFAULT
'
SELECT 1
  FROM DUAL
 WHERE /* JOUR  */ (TRIM(TO_CHAR(SYSDATE,''DAY'',''NLS_DATE_LANGUAGE = AMERICAN'')) IN (''MONDAY'',''TUESDAY'',''WEDNESDAY'',''THURSDAY'',''FRIDAY'',''SATURDAY'',''SUNDAY''))
   AND /* HEURE */ (TO_CHAR(SYSDATE,''HH24:MI'') BETWEEN ''00:00'' AND ''23:59'')
'                                                          
                                                                   NOT NULL
  ,FORMULE_NOTIF_DIF    VARCHAR2(2000)
  ,COMMENTAIRE          VARCHAR2(4000)
)
TABLESPACE SDBM_DATA
MONITORING;


INSERT INTO DESTI_NOTIF_DETAIL
   SELECT DESTI_NOTIF
         ,TYPE_NOTIF
         ,ADRESSE
         ,RETRAIT_ACCENT
         ,SUPPORT_FICHIER
         ,SQL_HORAIRE
         ,TO_CHAR(NULL)
         ,COMMENTAIRE
     FROM DESTI_NOTIF_DETAIL_028;
     
DROP TABLE DESTI_NOTIF_DETAIL_028 PURGE;


ALTER TABLE DESTI_NOTIF_DETAIL
   ADD CONSTRAINT DND_CHK_RETRAIT_ACCENT
      CHECK (RETRAIT_ACCENT IN (/* Vrai */ 'VR',/* Faux */ 'FA'));

ALTER TABLE DESTI_NOTIF_DETAIL
   ADD CONSTRAINT DND_CHK_SUPPORT_FICHIER
      CHECK (SUPPORT_FICHIER IN (/* Vrai */ 'VR',/* Faux */ 'FA'));


ALTER TABLE DESTI_NOTIF_DETAIL
   ADD CONSTRAINT DND_PK_DESTI_NOTIF PRIMARY KEY (DESTI_NOTIF, TYPE_NOTIF, ADRESSE)
      USING INDEX
      TABLESPACE SDBM_DATA;


ALTER TABLE DESTI_NOTIF_DETAIL
   ADD CONSTRAINT DND_FK_DESTI_NOTIF
       FOREIGN KEY (DESTI_NOTIF) REFERENCES DESTI_NOTIF
       ON DELETE CASCADE;

ALTER TABLE DESTI_NOTIF_DETAIL
   ADD CONSTRAINT DND_FK_TYPE_NOTIF
       FOREIGN KEY (TYPE_NOTIF) REFERENCES PARAMETRE_NOTIF_EXT;



CREATE TABLE SDBM.NOTIF_DIF
(
   DH_NOTIFICATION      DATE            DEFAULT SYSDATE     NOT NULL
  ,DH_ENVOI_CALC        DATE                                NOT NULL      
  ,TYPE_CIBLE           CHAR(2)                             NOT NULL      
  ,NOM_CIBLE            VARCHAR2(30)                        NOT NULL 
  ,DESTI_NOTIF          VARCHAR2(30)                        NOT NULL    
  ,TYPE_NOTIF           VARCHAR2(30)                        NOT NULL
  ,ADRESSE              VARCHAR2(100)                       NOT NULL
  ,NOM_EVENEMENT        VARCHAR2(100)
  ,NOM_OBJET            VARCHAR2(100)
  ,ENTETE               VARCHAR2(4000)
  ,MESSAGE              CLOB
  ,NOM_FICHIER          VARCHAR2(256)
  ,BLB_FICHIER          BLOB
  ,DH_ENVOI             DATE
)
LOB (MESSAGE)     STORE AS (DISABLE STORAGE IN ROW)
LOB (BLB_FICHIER) STORE AS (DISABLE STORAGE IN ROW)
TABLESPACE SDBM_DATA
MONITORING;



ALTER TABLE TACHE_AGT
   ADD
   ( 
      TYPE_NOTIF_OPT          CHAR(2)
     ,TYPE_NOTIF_JOURNAL_OPT  CHAR(2)
     ,DESTI_NOTIF_OPT         VARCHAR2(30)
   );

ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_CHK_TYPE_NOTIF_OPT
      CHECK (TYPE_NOTIF_OPT IN (/* Sur erreur */ 'OF', /* Toujours */ 'AL'));

ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_CHK_TYPE_NOTIF_JOURNAL_OPT
      CHECK (TYPE_NOTIF_JOURNAL_OPT IN (/* Sur erreur */ 'OF',/* Vrai */ 'VR',/* Faux */ 'FA'));

ALTER TABLE TACHE_AGT
   ADD CONSTRAINT TAC_FK_DESTI_NOTIF_OPT
       FOREIGN KEY (DESTI_NOTIF_OPT) REFERENCES DESTI_NOTIF;



ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_FK_CIBLE;

ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_FK_DESTI_NOTIF;

ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_FK_EVENEMENT;

ALTER TABLE REPARATION_EVEN_CIBLE
   DROP CONSTRAINT REC_FK_EVENEMENT_CIBLE;

ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_CHK_TYPE_CIBLE;

ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE CIBLE
   DROP CONSTRAINT EVC_CHK_VERIFICATION;

ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_PK_EVENEMENT_CIBLE;

ALTER TABLE EVENEMENT_CIBLE RENAME TO EVENEMENT_CIBLE_028;
CREATE TABLE EVENEMENT_CIBLE
(
   TYPE_CIBLE           CHAR(2)         DEFAULT 'BD'                             NOT NULL
  ,SOUS_TYPE_CIBLE      CHAR(2)         DEFAULT 'OR'                             NOT NULL
  ,NOM_CIBLE            VARCHAR2(30)                                             NOT NULL
  ,NOM_EVENEMENT        VARCHAR2(100)                                            NOT NULL
  ,VERIFICATION         CHAR(2)         DEFAULT 'AC'                             NOT NULL
  ,DH_PROCHAINE_VERIF   DATE            DEFAULT SYSDATE                          NOT NULL
  ,DH_LOC_DERN_VERIF    DATE            DEFAULT SYSDATE                          NOT NULL
  ,TS_UTC_DERN_VERIF    TIMESTAMP       DEFAULT SYSTIMESTAMP AT TIME ZONE 'UTC'  NOT NULL
  ,INTERVAL             VARCHAR2(500)
  ,DESTI_NOTIF          VARCHAR2(30)
)
TABLESPACE SDBM_DATA
MONITORING;

INSERT INTO EVENEMENT_CIBLE
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_CIBLE
  ,NOM_EVENEMENT
  ,VERIFICATION
  ,DH_PROCHAINE_VERIF
  ,INTERVAL
  ,DESTI_NOTIF
)
SELECT TYPE_CIBLE
      ,SOUS_TYPE_CIBLE
      ,NOM_CIBLE
      ,NOM_EVENEMENT
      ,VERIFICATION
      ,DH_PROCHAINE_VERIF
      ,INTERVAL
      ,DESTI_NOTIF
  FROM EVENEMENT_CIBLE_028;

DROP TABLE EVENEMENT_CIBLE_028 PURGE;


ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_CHK_TYPE_CIBLE
      CHECK (TYPE_CIBLE IN (/* Base de données */ 'BD'));

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS'));

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_CHK_VERIFICATION
      CHECK (VERIFICATION  IN (/* Activée */ 'AC',/* Inactif */ 'IN'));

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_PK_EVENEMENT_CIBLE PRIMARY KEY (TYPE_CIBLE, SOUS_TYPE_CIBLE, NOM_CIBLE, NOM_EVENEMENT)
      USING INDEX
      TABLESPACE SDBM_DATA;

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_FK_CIBLE
       FOREIGN KEY (TYPE_CIBLE, SOUS_TYPE_CIBLE, NOM_CIBLE) REFERENCES CIBLE (TYPE_CIBLE, SOUS_TYPE_CIBLE, NOM_CIBLE)
       ON DELETE CASCADE;

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_FK_DESTI_NOTIF
       FOREIGN KEY (DESTI_NOTIF) REFERENCES DESTI_NOTIF;

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_FK_EVENEMENT
       FOREIGN KEY (TYPE_CIBLE, SOUS_TYPE_CIBLE, NOM_EVENEMENT) REFERENCES EVENEMENT
       ON DELETE CASCADE;

ALTER TABLE REPARATION_EVEN_CIBLE
   ADD CONSTRAINT REC_FK_EVENEMENT_CIBLE
       FOREIGN KEY (TYPE_CIBLE, SOUS_TYPE_CIBLE, NOM_CIBLE, NOM_EVENEMENT) REFERENCES EVENEMENT_CIBLE
       ON DELETE CASCADE;

CREATE OR REPLACE TRIGGER SDBM.EVC_TR_AD_FERMETURE_EVENEMENT

/******************************************************************
  TRIGGER : EVC_TR_AD_FERMETURE_EVENEMENT
  AUTEUR  : Benoit Bouthillier 2008-09-18
 ------------------------------------------------------------------
  BUT : Force la fermeture des événements ouvert dans le cas ou
        la vérification d'un événement sur une cible est retirée.

*******************************************************************/

   AFTER DELETE
   ON EVENEMENT_CIBLE
   FOR EACH ROW

BEGIN

   UPDATE HIST_EVENEMENT_CIBLE
      SET DH_FERMETURE = SYSDATE
    WHERE TYPE_CIBLE    = :OLD.TYPE_CIBLE
      AND NOM_CIBLE     = :OLD.NOM_CIBLE
      AND NOM_EVENEMENT = :OLD.NOM_EVENEMENT
      AND DH_FERMETURE  IS NULL;

END;
/


DELETE FROM DEFAUT
 WHERE CLE LIKE 'FR%' OR CLE LIKE 'AN%';

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_DN'
  ,'NON-DISPONIBLE'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_UP'
  ,'DISPONIBLE'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_DN'
  ,'DOWN'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_UP'
  ,'UP'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_ER'
  ,'PROBLÈME'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_OK'
  ,'RÉSOLUTION'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_--'
  ,'ÉVÉNEMENT'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_ER'
  ,'PROBLEM'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_OK'
  ,'CLEARED'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_--'
  ,'EVENT'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_AG'
  ,'ALERTE'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_AG'
  ,'ALERT'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'FR_AGENT'
  ,'RÉSULTAT (TÂCHE)'
);

INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'AN_AGENT'
  ,'RESULT (JOB)'
);


UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT ''N/A''
      ,''Attention : '' || COUNT(1) || '' nouveau(x) enregistrement(s) dans le journal SDBM depuis '' || TO_CHAR({LAST_SYSDATE},''YYYY/MM/DD HH24:MI:SS'') || ''.''
  FROM SDBM.JOURNAL
 WHERE DH_JOURNAL >= {LAST_SYSDATE}
   AND NIVEAU NOT IN (''INFO'',''CONFIG'')
 HAVING COUNT(1) > 0
'
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR'
   AND NOM_EVENEMENT   = 'SDBM.ERROR';

DELETE FROM SDBM.EVENEMENT_DEFAUT_TRADUCTION
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR'
   AND NOM_EVENEMENT   = 'SDBM.ERROR';
   
INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.ERROR'
  ,'''Attention : '' || COUNT(1) || '' nouveau(x) enregistrement(s) dans le journal SDBM depuis '
  ,'''Warning : '' || COUNT(1) || '' new record(s) in the SDBM events log since '
  ,'Vérification qu''il n''existe pas d''erreur dans je journal d''evénement SDBM (serveur local et distant devrait être enregistrés)'
  ,'Validate that no error exists into SDBM event log (local and remote server should be registered)'
);


-- SDBM.WARNING
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,TYPE_FERMETURE
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.WARNING'
  ,'AU'
  ,'
SELECT REPLACE(SUBSTR(SUBSTR(TEXTE,25),1,INSTR(SUBSTR(TEXTE,25),'' ('',INSTR(SUBSTR(TEXTE,25),'' target'')) - 1),'' target'','''')
      ,TO_CHAR(DH_JOURNAL,''YYYY/MM/DD:HH24:MI:SS'') || '' : '' || TEXTE
  FROM SDBM.JOURNAL
 WHERE DH_JOURNAL >= {LAST_SYSDATE}
   AND SOURCE   = ''SDBMSrv''
   AND NIVEAU   = ''WARNING''
   AND TEXTE LIKE ''Unable to process event %''
'
  ,'SYSDATE + 15/1440'
  ,'---'
  ,30
);

INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.WARNING'
  ,'''!!NULL!!'''
  ,'''!!NULL!!'''
  ,'Envoi des messages du journal SDBM (WARNING : Unable to process event ...)'
  ,'Send message from SDBM event log (WARNING : Unable to process event ...)'
);


UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT ''N/A''
      ,DECODE(COUNT(1)
             ,1,COUNT(1) || '' fichier de la base de données n''''a pas été sauvegardé dans RMAN''   || DECODE(MIN(COMPLETION_TIME)
                                                                                                           ,TO_DATE(NULL),''.''
                                                                                                           ,'' depuis le '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                                           )
             ,COUNT(1) || '' fichiers de la base de données n''''ont pas été sauvegardés dans RMAN'' || DECODE(MIN(COMPLETION_TIME)
                                                                                                           ,TO_DATE(NULL),''.''
                                                                                                           ,'' depuis le '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                                           )
             )
  FROM (
         SELECT MAX(BDF.COMPLETION_TIME) "COMPLETION_TIME"
           FROM V$DATAFILE        DBF
               ,V$BACKUP_DATAFILE BDF
          WHERE DBF.FILE#    = BDF.FILE#(+) 
            AND DBF.ENABLED != ''READ ONLY'' 
          GROUP BY DBF.FILE#
       )
 WHERE COMPLETION_TIME < SYSDATE - 7
    OR COMPLETION_TIME IS NULL
HAVING COUNT(1) > 0
'
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR'
   AND NOM_EVENEMENT   = 'RMAN_DATAFILE';

DELETE FROM SDBM.EVENEMENT_DEFAUT_TRADUCTION
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR'
   AND NOM_EVENEMENT   = 'RMAN_DATAFILE';
   
INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'RMAN_DATAFILE'
  ,(SELECT SUBSTR(COMMANDE,54,1092) FROM SDBM.EVENEMENT WHERE NOM_EVENEMENT = 'RMAN_DATAFILE')
  ,       ',1,COUNT(1) || '' file of the database was not backup within RMAN''   || DECODE(MIN(COMPLETION_TIME)
                                                                                          ,TO_DATE(NULL),''.''
                                                                                          ,'' since '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                          )
              ,COUNT(1) || '' files of the database were not backup within RMAN'' || DECODE(MIN(COMPLETION_TIME)
                                                                                        ,TO_DATE(NULL),''.''
                                                                                        ,'' since '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                        )'
  ,'Vérification de l''exécution des prises de copie RMAN (DATAFILE)'
  ,'Validate that RMAN backup are running (DATAFILE)'
);



ALTER TABLE SDBM.DEFAUT    CACHE;
ALTER TABLE SDBM.PARAMETRE CACHE;


@../_package\ps-sdbm_util.sql
@../_package\pb-sdbm_util.sql
@../_package\pb-sdbm_smtp.sql
@../_package\pb-sdbm_agent.sql
@../_package\pb-sdbm_base.sql


SDBMSrv version = "0.08 - Beta";
SDBMAgt version = "0.14 - Beta";



/* ********************* */
/* Nouvelle version APEX */
/* ********************* */



/* Ajout SDBM.WARNING */
-> Changement via l'interface EVENEMENT_CIBLE + SDBM.WARNING@SDBM

/* Correction commentaire dans les événements SDBM */
-> Changement via l'interface Web Anglais -> Fraçais -> Anglais



#
# Installation Apache
#

# Obtenir httpd-2.2.21.tar.gz et le placer sous /tmp
cd /tmp
gunzip httpd-2.2.21.tar.gz
tar -xvf httpd-2.2.21.tar
rm -f httpd-2.2.21.tar

cd /tmp/httpd-2.2.21
./configure --enable-cache --enable-proxy --enable-ssl --enable-setenvif
make
make install

cd /tmp
rm -Rf httpd-2.2.21


#
# Update Linux
#
yum update
reboot

- Modification de /boot/grub/grub.conf

yum remove kernel-2.6.18-194*
yum remove kernel-devel-2.6.18-194*

- Modification de /etc/init.d/update-ip.sh
- Modification de /etc/init.d/network (/etc/init.d/update-ip.sh)




---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 8 a  -   B e t a --
---------------------------------------------
---------------------------------------------

GRANT ALTER SYSTEM             TO SDBM;
GRANT SELECT ON SDBM.PARAMETRE TO SDBMON;

@../_package\pb-sdbm_util.sql
@../_package\pb-sdbm_agent.sql

CREATE OR REPLACE VIEW SDBM.APEX_STATUT_SESSION_SDBM
AS 
  SELECT 'N/D'                                               "SERVEUR"
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
         AND UPPER(CIB.NOM_SERVEUR) NOT IN (SELECT UPPER(CLIENT_IDENTIFIER) "SERVEUR"
                                              FROM V$SESSION
                                             WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                           )
      UNION
      SELECT UPPER(NOM_SERVEUR)                                 "SERVEUR"
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
         AND NOM_SERVEUR NOT IN (SELECT UPPER(CLIENT_IDENTIFIER) "SERVEUR"
                                   FROM V$SESSION
                                  WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                )
   )
   UNION ALL
   SELECT DECODE(SUBSTR(SESS.MODULE,1,7)
                ,'SDBMSRV',UPPER(SUBSTR(SESS.CLIENT_INFO,INSTR(SESS.CLIENT_INFO,'running on ') + 11))
                ,UPPER(CLIENT_IDENTIFIER)
                )                                                                                           "SERVEUR"
         ,SESS.MODULE                                                                                       "MODULE"
         ,SUBSTR(SESS.CLIENT_INFO,1,INSTR(SESS.CLIENT_INFO,' running on ')-1)                               "DESCRIPTION"
         ,DECODE(SUBSTR(SESS.MODULE,1,7)
                ,'SDBMSRV',SESS.ACTION || ' (' || NVL(CLIENT_IDENTIFIER,'--') || ')'
                ,SESS.ACTION
                )                                                                                           "DERNIERE_ACTION"
         ,TO_CHAR(SESS.LOGON_TIME,'YYYY/MM/DD:HH24:MI:SS')                                                  "ORACLE_LOGON"
         ,TO_CHAR(PROC.SPID)                                                                                "ORACLE_SPID"
         ,TO_CHAR(SESS.SID)                                                                                 "ORACLE_SID"
         ,TO_CHAR(SESS.SERIAL#)                                                                             "ORACLE_SERIAL"
         ,STATUS                                                                                            "ORACLE_STATUS"
         ,DECODE(SUBSTR(SESS.MODULE,1,7)
                ,'SDBMSRV',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') > (SELECT (FREQU_VERIF_CIBLE_SEC + 60) / 86400 FROM PARAMETRE)) THEN 3 ELSE 1 END)
                ,'SDBMAGT',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') > (SELECT (FREQU_VERIF_AGENT     + 60) / 86400 FROM PARAMETRE)) THEN 3 ELSE 1 END)
                )                                                                                           "MISE_EN_EVIDENCE"
     FROM V$SESSION SESS
         ,V$PROCESS PROC
    WHERE SESS.PADDR = PROC.ADDR
      AND SESS.MODULE LIKE 'SDBM___ - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA;
