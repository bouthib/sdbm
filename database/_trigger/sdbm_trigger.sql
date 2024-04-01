-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


--
-- Script :
--    sdbm_trigger.sql
--
-- Description :
--    Mise en place des triggers du schéma SDBM.
--


CREATE OR REPLACE TRIGGER SDBM.PAR_TR_BIUD_PAR_NOTIF_EXT

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
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


CREATE OR REPLACE TRIGGER SDBM.PAR_TR_BIU_MOT_PASSE

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : PAR_TR_BIU_MOT_PASSE
  AUTEUR  : Benoit Bouthillier 2022-01-15
 ------------------------------------------------------------------
  BUT : Effectue l'encryption des mots de passes sur la table.

*******************************************************************/

   BEFORE INSERT OR UPDATE
   ON PARAMETRE
   FOR EACH ROW

BEGIN

   IF (INSERTING) THEN

      -- Si le nom d'usager ou le mot de passe est NULL
      IF (:NEW.NOM_USAGER_SMTP IS NULL OR :NEW.MDP_USAGER_SMTP IS NULL) THEN

         :NEW.MDP_USAGER_SMTP := NULL;

      ELSE
         
         -- Encryption du mot de passe
         :NEW.MDP_USAGER_SMTP := SDBM_UTIL.ENCRYPTER_MDP_SMTP(:NEW.NOM_USAGER_SMTP,:NEW.MDP_USAGER_SMTP);

      END IF;

      -- Si le chemin du wallet ou le mot de passe est NULL
      IF (:NEW.CHEMIN_WALLET_SMTP IS NULL OR :NEW.MDP_WALLET_SMTP IS NULL) THEN

         :NEW.MDP_WALLET_SMTP    := NULL;

      ELSE
         
         -- Encryption du mot de passe
         :NEW.MDP_WALLET_SMTP := SDBM_UTIL.ENCRYPTER_MDP_WALLET_SMTP(:NEW.CHEMIN_WALLET_SMTP,:NEW.MDP_WALLET_SMTP);

      END IF;

   ELSE

      -- Si le nom d'usager ou le mot de passe est modifié
      IF (UPDATING('NOM_USAGER_SMTP') OR UPDATING('MDP_USAGER_SMTP') = TRUE) THEN

         -- Si le nom d'usager ou le mot de passe est NULL
         IF (:NEW.NOM_USAGER_SMTP IS NULL OR :NEW.MDP_USAGER_SMTP IS NULL) THEN

            :NEW.MDP_USAGER_SMTP := NULL;
  
         ELSE
         
            -- Encryption du mot de passe
            :NEW.MDP_USAGER_SMTP := SDBM_UTIL.ENCRYPTER_MDP_SMTP(:NEW.NOM_USAGER_SMTP,:NEW.MDP_USAGER_SMTP);

         END IF;

      END IF;

      -- Si le chemin du wallet ou le mot de passe est modifié
      IF (UPDATING('CHEMIN_WALLET_SMTP') OR UPDATING('MDP_WALLET_SMTP') = TRUE) THEN

         -- Si le nom d'usager ou le mot de passe est NULL
         IF (:NEW.CHEMIN_WALLET_SMTP IS NULL OR :NEW.MDP_WALLET_SMTP IS NULL) THEN

            :NEW.MDP_WALLET_SMTP := NULL;
  
         ELSE
         
            -- Encryption du mot de passe
            :NEW.MDP_WALLET_SMTP := SDBM_UTIL.ENCRYPTER_MDP_WALLET_SMTP(:NEW.CHEMIN_WALLET_SMTP,:NEW.MDP_WALLET_SMTP);

         END IF;

      END IF;

   END IF;

END;
/


CREATE OR REPLACE TRIGGER SDBM.CIB_TR_BIU_MOT_PASSE

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : CIB_TR_BIU_MOT_PASSE
  AUTEUR  : Benoit Bouthillier 2008-09-18
 ------------------------------------------------------------------
  BUT : Effectue l'encryption du mot de passe d'une cible.

*******************************************************************/

   BEFORE INSERT OR UPDATE
   ON CIBLE
   FOR EACH ROW

BEGIN

   IF (INSERTING) THEN

      IF (:NEW.MDP_USAGER IS NOT NULL) THEN

         -- Encryption du mot de passe
         :NEW.MDP_USAGER := SDBM_UTIL.ENCRYPTER_MDP_CIBLE(:NEW.NOM_CIBLE,:NEW.MDP_USAGER);

      END IF;

   ELSE

      -- Validation (le code de la cible ne peut pas être modifié)
      IF (:OLD.NOM_CIBLE <> :NEW.NOM_CIBLE) THEN
         RAISE_APPLICATION_ERROR(-20000,'Le nom de la cible ne peut être modifié.');
      END IF;

      -- Si la modification est un chagement de mot de passe
      IF (UPDATING('MDP_USAGER') = TRUE) THEN

         IF (:NEW.MDP_USAGER IS NOT NULL) THEN

            -- Encryption du mot de passe
            :NEW.MDP_USAGER := SDBM_UTIL.ENCRYPTER_MDP_CIBLE(:NEW.NOM_CIBLE,:NEW.MDP_USAGER);

         ELSE

            :NEW.MDP_USAGER := :OLD.MDP_USAGER;

         END IF;

      END IF;

   END IF;

END;
/


CREATE OR REPLACE TRIGGER SDBM.EVC_TR_AD_FERMETURE_EVENEMENT

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
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


CREATE OR REPLACE TRIGGER SDBM.CIB_TR_BU_REMISE_ACTIF

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : CIB_TR_BU_REMISE_ACTIF
  AUTEUR  : Benoit Bouthillier 2008-09-18
 ------------------------------------------------------------------
  BUT : Force une DH_DERN_VERIF courrante pour éviter un message
        de retard de la vérification SDBM.

*******************************************************************/

   BEFORE UPDATE
   ON CIBLE
   FOR EACH ROW
   WHEN (OLD.NOTIFICATION = 'IN' AND NEW.NOTIFICATION = 'AC')

BEGIN

   :NEW.DH_DERN_VERIF := SYSDATE;

END;
/


CREATE OR REPLACE TRIGGER SDBM.USA_TR_BIU_MOT_PASSE

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : USA_TR_BIU_MOT_PASSE
  AUTEUR  : Benoit Bouthillier 2008-06-27
 ------------------------------------------------------------------
  BUT : Mise à jour des enregistrement de contrôle et encryption du
        mot de passe s'il y a lieu.

*******************************************************************/

   BEFORE INSERT OR UPDATE
   ON USAGER
   FOR EACH ROW

BEGIN

   IF (INSERTING) THEN

      -- Traitement du nom de l'usager et du mot de passe
      :NEW.NOM_USAGER      := UPPER(:NEW.NOM_USAGER);
      :NEW.MOT_PASSE       := SDBM_APEX_UTIL.ENCRYPTER_MDP_USAGER(:NEW.NOM_USAGER,:NEW.MOT_PASSE);

      :NEW.USAGER_CREATION := NVL(V('APP_USER'),'N/A');

   ELSE
   
      -- Validation (le code d'usager ne peut pas être modifié)
      IF (:OLD.NOM_USAGER <> :NEW.NOM_USAGER) THEN
         RAISE_APPLICATION_ERROR(-20000,'Le code usager ne peut être modifié.');
      END IF;

      -- Si la modification est autre chose qu'une connexion
      IF (UPDATING('DH_DERN_CONNEXION') = FALSE) THEN

         IF (UPDATING('MOT_PASSE')) THEN
            :NEW.MOT_PASSE      := SDBM_APEX_UTIL.ENCRYPTER_MDP_USAGER(:OLD.NOM_USAGER,:NEW.MOT_PASSE);
         END IF;

         :NEW.DH_DERN_MODIF     := SYSDATE;
         :NEW.USAGER_DERN_MODIF := NVL(V('APP_USER'),'N/A');

      END IF;

   END IF;

END USA_TR_BIU_MOT_PASSE;
/


CREATE SEQUENCE SDBM.JOU_ID_JOURNAL
   MINVALUE 1
   MAXVALUE 9999999999
   CYCLE
   NOCACHE;


CREATE OR REPLACE TRIGGER SDBM.JOU_TR_INIT_ID_JOURNAL

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : JOU_TR_INIT_ID_JOURNAL
  AUTEUR  : Benoit Bouthillier 2009-03-14
 ------------------------------------------------------------------
  BUT : Initialisation de la clé primaire.

*******************************************************************/

   BEFORE INSERT
   ON JOURNAL
   FOR EACH ROW

BEGIN

   SELECT JOU_ID_JOURNAL.NEXTVAL
     INTO :NEW.ID_JOURNAL
     FROM DUAL;

END JOU_TR_INIT_ID_JOURNAL;
/


CREATE SEQUENCE SDBM.VP_ID_VOLUME_PHY
   MINVALUE 1
   MAXVALUE 999999
   NOCYCLE
   NOCACHE;


CREATE OR REPLACE TRIGGER SDBM.VP_TR_INIT_ID_VOLUME_PHY

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : VP_TR_INIT_ID_VOLUME_PHY
  AUTEUR  : Benoit Bouthillier 2009-02-13
 ------------------------------------------------------------------
  BUT : Initialisation de la clé primaire.

*******************************************************************/

   BEFORE INSERT
   ON VOLUME_PHY
   FOR EACH ROW

BEGIN

   SELECT VP_ID_VOLUME_PHY.NEXTVAL
     INTO :NEW.ID_VOLUME_PHY
     FROM DUAL;

END VP_TR_INIT_ID_VOLUME_PHY;
/


CREATE SEQUENCE SDBM.HTA_ID_SOUMISSION
   MINVALUE 1
   MAXVALUE 9999999999
   CYCLE
   NOCACHE;


CREATE OR REPLACE TRIGGER SDBM.CDDDF_TR_ID_VOLUME_PHY

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
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


CREATE OR REPLACE TRIGGER SDBM.CDAD_TR_MAJ_VOLUME_PHY

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : CDAD_TR_MAJ_VOLUME_PHY
  AUTEUR  : Benoit Bouthillier 2012-05-22
 ------------------------------------------------------------------
  BUT : Mise à jour de la table VOLUME_PHY (diskgroup ASM).

*******************************************************************/

   BEFORE INSERT
   ON CD_ASM_DISKGROUP
   FOR EACH ROW

DECLARE

   V_INDICATEUR_MODIF NUMBER(1);

BEGIN

   -- Vérification si une mise à jour est requise
   SELECT DISTINCT 1
     INTO V_INDICATEUR_MODIF
     FROM VOLUME_PHY
    WHERE DESC_VOLUME_PHY     = :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
      AND CHEMIN_ACCES_DEFAUT = '+' || :NEW.DISKGROUP_NAME || '/'
      AND MAJ_CD_AUTORISE     = 'VR'
      AND DH_DERN_MAJ         < :NEW.DH_COLLECTE_DONNEE
      AND STATUT              = 'AC'
      AND (
                TOTAL_MB != :NEW.TOTAL_MB
             OR FREE_MB  != :NEW.FREE_MB
          );

   -- Mise à jour requise
   UPDATE VOLUME_PHY
      SET TOTAL_MB           = NVL(:NEW.TOTAL_MB,0)
         ,FREE_MB            = NVL(:NEW.FREE_MB,0)
         ,DH_DERN_MAJ        = :NEW.DH_COLLECTE_DONNEE
         ,NOM_CIBLE_DERN_MAJ = :NEW.NOM_CIBLE
    WHERE DESC_VOLUME_PHY     = :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
      AND CHEMIN_ACCES_DEFAUT = '+' || :NEW.DISKGROUP_NAME || '/'
      AND MAJ_CD_AUTORISE     = 'VR'
      AND DH_DERN_MAJ         < :NEW.DH_COLLECTE_DONNEE
      AND STATUT              = 'AC'
      AND (
                TOTAL_MB != :NEW.TOTAL_MB
             OR FREE_MB  != :NEW.FREE_MB
          );

EXCEPTION

   WHEN NO_DATA_FOUND THEN

      BEGIN

         -- Vérification si une insertion est requise
         SELECT DISTINCT 1
           INTO V_INDICATEUR_MODIF
           FROM VOLUME_PHY
          WHERE DESC_VOLUME_PHY = :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
            AND STATUT          = 'AC';
      
      EXCEPTION

         WHEN NO_DATA_FOUND THEN

            INSERT INTO VOLUME_PHY
            (
               DESC_VOLUME_PHY
              ,CHEMIN_ACCES_DEFAUT
              ,MAJ_CD_AUTORISE
              ,DH_DERN_MAJ
              ,TOTAL_MB
              ,FREE_MB
              ,NOM_CIBLE_DERN_MAJ
            )
            VALUES
            (
               :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
              ,'+' || :NEW.DISKGROUP_NAME || '/'
              ,'VR'
              ,:NEW.DH_COLLECTE_DONNEE
              ,NVL(:NEW.TOTAL_MB,0)
              ,NVL(:NEW.FREE_MB,0)
              ,:NEW.NOM_CIBLE
            );

      END;

END CDAD_TR_MAJ_VOLUME_PHY;
/


CREATE OR REPLACE TRIGGER SDBM.CDSC_TR_MAJ_CPU_CALC_DERN_PER

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  TRIGGER : CDSC_TR_MAJ_CPU_CALC_DERN_PER
  AUTEUR  : Benoit Bouthillier 2012-06-02
 ------------------------------------------------------------------
  BUT : Mise à jour de la table CD_SYSSTAT_CPU (calcul des colonnes
        C_DERN_PER).

*******************************************************************/

   BEFORE INSERT
   ON CD_SYSSTAT_CPU
   FOR EACH ROW

DECLARE

   V_DH_COLLECTE_DONNEE       CD_SYSSTAT_CPU.DH_COLLECTE_DONNEE%TYPE;
   V_HOST_NAME                CD_SYSSTAT_CPU.HOST_NAME%TYPE;
   V_INSTANCE_NAME            CD_SYSSTAT_CPU.INSTANCE_NAME%TYPE;
   V_STARTUP_TIME             CD_SYSSTAT_CPU.STARTUP_TIME%TYPE;
   V_CPU_USED_BY_SESSION_PREC CD_SYSSTAT_CPU.CPU_USED_BY_SESSION%TYPE;
   V_CPU_RECURSIVE_PREC       CD_SYSSTAT_CPU.CPU_RECURSIVE%TYPE;
   V_CPU_PARSE_TIME_PREC      CD_SYSSTAT_CPU.CPU_PARSE_TIME%TYPE;

BEGIN

   -- Recherche de la valeur précédente
   SELECT DH_COLLECTE_DONNEE
         ,HOST_NAME
         ,INSTANCE_NAME
         ,STARTUP_TIME
         ,CPU_USED_BY_SESSION
         ,CPU_RECURSIVE
         ,CPU_PARSE_TIME
     INTO V_DH_COLLECTE_DONNEE
         ,V_HOST_NAME
         ,V_INSTANCE_NAME
         ,V_STARTUP_TIME
         ,V_CPU_USED_BY_SESSION_PREC
         ,V_CPU_RECURSIVE_PREC
         ,V_CPU_PARSE_TIME_PREC
     FROM CD_SYSSTAT_CPU
    WHERE DH_COLLECTE_DONNEE = (SELECT MAX(DH_COLLECTE_DONNEE)
                                  FROM CD_SYSSTAT_CPU
                                 WHERE DH_COLLECTE_DONNEE < :NEW.DH_COLLECTE_DONNEE
                                   AND NOM_CIBLE          = :NEW.NOM_CIBLE
                               )
      AND NOM_CIBLE          = :NEW.NOM_CIBLE;

   -- Vérification pour redémarrage de l'instance
   IF (V_STARTUP_TIME = :NEW.STARTUP_TIME) THEN

      -- Situation régulière
      :NEW.CPU_USED_BY_SESSION_C_DERN_PER := ((:NEW.CPU_USED_BY_SESSION - V_CPU_USED_BY_SESSION_PREC) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_DH_COLLECTE_DONNEE) * 86400);
      :NEW.CPU_RECURSIVE_C_DERN_PER       := ((:NEW.CPU_RECURSIVE       - V_CPU_RECURSIVE_PREC      ) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_DH_COLLECTE_DONNEE) * 86400);
      :NEW.CPU_PARSE_TIME_C_DERN_PER      := ((:NEW.CPU_PARSE_TIME      - V_CPU_PARSE_TIME_PREC     ) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_DH_COLLECTE_DONNEE) * 86400);

   ELSE

      -- Redémarrage
      :NEW.CPU_USED_BY_SESSION_C_DERN_PER := ((:NEW.CPU_USED_BY_SESSION - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_STARTUP_TIME) * 86400);
      :NEW.CPU_RECURSIVE_C_DERN_PER       := ((:NEW.CPU_RECURSIVE       - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_STARTUP_TIME) * 86400);
      :NEW.CPU_PARSE_TIME_C_DERN_PER      := ((:NEW.CPU_PARSE_TIME      - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_STARTUP_TIME) * 86400);

   END IF;


EXCEPTION

   WHEN NO_DATA_FOUND THEN

      -- Première estimation
      :NEW.CPU_USED_BY_SESSION_C_DERN_PER := ((:NEW.CPU_USED_BY_SESSION - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - :NEW.STARTUP_TIME) * 86400);
      :NEW.CPU_RECURSIVE_C_DERN_PER       := ((:NEW.CPU_RECURSIVE       - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - :NEW.STARTUP_TIME) * 86400);
      :NEW.CPU_PARSE_TIME_C_DERN_PER      := ((:NEW.CPU_PARSE_TIME      - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - :NEW.STARTUP_TIME) * 86400);

END CDSC_TR_MAJ_CPU_CALC_DERN_PER;
/
