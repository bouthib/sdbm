-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM_SMTP
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_SMTP
  AUTEUR  : Benoit Bouthillier 2009-10-02 (2023-04-04)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures utilitaire
        SMTP pour le moniteur Oracle.

**********************************************************************/


   /******************************************************************
     CONSTANTE :
    *****************************************************************/

    -- Version du corps PL/SQL
    VERSION_PB CONSTANT VARCHAR2(4 CHAR) := '0.06';


   /******************************************************************
     VARIABLES GLOBALES :
    *****************************************************************/

    -- Timestamp de la dernière erreur
    G_TS_LAST_ERREUR TIMESTAMP := NULL;


   /******************************************************************
                      FONCTIONS ET PROCEDURES PUBLIC
   ******************************************************************/


   /******************************************************************
     PROCEDURE : VERSION
     AUTEUR    : Benoit Bouthillier 2009-10-02
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de retourner la version de
           de l'entête PL/SQL et du code de ce package Oracle.
   
           Particularité:
              SERVEROUTPUT doit être activé

     PARAMETRES: N/A

   ******************************************************************/
   PROCEDURE VERSION
   IS

   BEGIN

      DBMS_OUTPUT.PUT_LINE('Version');
      DBMS_OUTPUT.PUT_LINE('----------------------------');

      -- Affichage de la version de l'entête PL/SQL (PS)
      DBMS_OUTPUT.PUT_LINE('Package Specification : ' || VERSION_PS);

      -- Affichage de la version du code PL/SQL (PB)
      DBMS_OUTPUT.PUT_LINE('Package Body          : ' || VERSION_PB);

   END VERSION;


   /******************************************************************
     PROCEDURE : ENVOYER_SMTP
     AUTEUR    : Benoit Bouthillier 2010-06-03 (2023-04-04)
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de procéder à l'envoi d'un
           courriel.
   
     PARAMETRES: Adresse de courriel - destinataire  (A_DESTINATAIRE)
                 Sujet                               (A_SUJET)
                 Corps du message                    (A_MESSAGE)
                 Nom du fichier (optionnel)          (A_NOM_FICHIER)
                 Données du fichier (optionnel)      (A_BLB_FICHIER)

   *******************************************************************/
   PROCEDURE ENVOYER_SMTP
   (
      A_DESTINATAIRE IN VARCHAR2               -- Adresse de courriel - destinataire
     ,A_SUJET        IN VARCHAR2               -- Sujet
     ,A_MESSAGE      IN VARCHAR2               -- Corps du message
     ,A_NOM_FICHIER  IN VARCHAR2 DEFAULT NULL  -- Nom du fichier (optionnel)
     ,A_BLB_FICHIER  IN BLOB     DEFAULT NULL  -- Données du fichier (optionnel)
   )
   IS

      --
      -- Constantes
      --
      
      -- Frontière MIME MULTIPART
      BOUNDARY   CONSTANT VARCHAR2(50 CHAR)   := '-----7D81B75CCC90D2974F7A1CBD';
      F_BOUNDARY CONSTANT VARCHAR2(50 CHAR)   := '--' || BOUNDARY         || UTL_TCP.CRLF;
      L_BOUNDARY CONSTANT VARCHAR2(50 CHAR)   := '--' || BOUNDARY || '--' || UTL_TCP.CRLF;

      -- Definition MIME MULTIPART
      MP_MI_SIZE CONSTANT BINARY_INTEGER := 2016;
      MP_MI_TYPE CONSTANT VARCHAR2(256 CHAR)  := 'multipart/mixed; boundary="' || BOUNDARY || '"';


      -- Variables locales
      V_TS_CURRENT         TIMESTAMP;
      V_SERVEUR_SMTP       PARAMETRE.SERVEUR_SMTP%TYPE;
      V_PORT_SMTP          PARAMETRE.PORT_SMTP%TYPE;
      V_NOM_USAGER_SMTP    PARAMETRE.NOM_USAGER_SMTP%TYPE;
      V_MDP_USAGER_SMTP    PARAMETRE.MDP_USAGER_SMTP%TYPE;
      V_EXPEDITEUR_SMTP    PARAMETRE.EXPEDITEUR_SMTP%TYPE;
      V_STARTTLS_SMTP      PARAMETRE.STARTTLS_SMTP%TYPE;
      V_CHEMIN_WALLET_SMTP PARAMETRE.CHEMIN_WALLET_SMTP%TYPE;
      V_MDP_WALLET_SMTP    PARAMETRE.MDP_WALLET_SMTP%TYPE;

      V_CONNEXION          UTL_SMTP.CONNECTION;
      V_DESTINATAIRE       VARCHAR2(4000 CHAR) := TRIM(BOTH ';' FROM REPLACE(A_DESTINATAIRE,' ',''));
      V_IND_SORTIE         BOOLEAN             := FALSE;
      V_POS_INIT           NUMBER(4)           := 0;
      V_POS_TRAI           NUMBER(4)           := 0;
      
      V_TAMPON_MESSAGE     CLOB;
      V_GROSSEUR_BLOB      NUMBER;
      V_GROSSEUR_MP        BINARY_INTEGER := MP_MI_SIZE;
      V_TAMPON_MP          RAW(2048);

      V_SQLERRM            VARCHAR2(512 CHAR);

   BEGIN

      -- Vérification si l'erreur était commune
      V_TS_CURRENT := SYSTIMESTAMP AT TIME ZONE 'UTC';
       
      IF ((G_TS_LAST_ERREUR IS NOT NULL) AND (EXTRACT(  HOUR FROM (V_TS_CURRENT - G_TS_LAST_ERREUR)) * 3600
                                            + EXTRACT(MINUTE FROM (V_TS_CURRENT - G_TS_LAST_ERREUR)) *   60
                                            + EXTRACT(SECOND FROM (V_TS_CURRENT - G_TS_LAST_ERREUR)) *    1 < 30)) THEN

         RAISE_APPLICATION_ERROR(-20001,'The previous error was ORA-29278: SMTP transient error: 421 Service not available. A new attempt will take place after 30 seconds.');

      END IF;

      -- Recherche du nom de serveur SMTP
      SELECT SERVEUR_SMTP
            ,PORT_SMTP
            ,NOM_USAGER_SMTP
            ,MDP_USAGER_SMTP
            ,EXPEDITEUR_SMTP
            ,STARTTLS_SMTP
            ,CHEMIN_WALLET_SMTP
	    ,MDP_WALLET_SMTP
        INTO V_SERVEUR_SMTP
            ,V_PORT_SMTP
            ,V_NOM_USAGER_SMTP
            ,V_MDP_USAGER_SMTP
            ,V_EXPEDITEUR_SMTP
	    ,V_STARTTLS_SMTP
	    ,V_CHEMIN_WALLET_SMTP
	    ,V_MDP_WALLET_SMTP
        FROM PARAMETRE;
       
      -- Ouverture de la connexion au serveur de courriel
      IF (V_STARTTLS_SMTP = 'FA') THEN

         V_CONNEXION := UTL_SMTP.OPEN_CONNECTION(V_SERVEUR_SMTP,V_PORT_SMTP);
	
         -- Engage la conversation
	 UTL_SMTP.HELO(V_CONNEXION,SYS_CONTEXT('USERENV','SERVER_HOST'));

      ELSE	
			       
         V_CONNEXION := UTL_SMTP.OPEN_CONNECTION(HOST            => V_SERVEUR_SMTP
                                                ,PORT            => V_PORT_SMTP
                                                ,WALLET_PATH     => V_CHEMIN_WALLET_SMTP
                                                ,WALLET_PASSWORD => SDBM_UTIL.DECRYPTER_MDP_SMTP(V_CHEMIN_WALLET_SMTP,V_MDP_WALLET_SMTP) 
                                                );
         -- Engage la conversation
         UTL_SMTP.HELO(V_CONNEXION,SYS_CONTEXT('USERENV','SERVER_HOST'));
         UTL_SMTP.STARTTLS(V_CONNEXION);

      END IF;
 
      -- Authentification (si requis)
      IF (V_NOM_USAGER_SMTP IS NOT NULL AND V_MDP_USAGER_SMTP IS NOT NULL) THEN

         UTL_SMTP.AUTH(V_CONNEXION
                      ,V_NOM_USAGER_SMTP
                      ,SDBM_UTIL.DECRYPTER_MDP_SMTP(V_NOM_USAGER_SMTP,V_MDP_USAGER_SMTP)
                      ,'PLAIN'
                      );

      END IF;

      -- Définition de l'exépéditeur
      UTL_SMTP.MAIL(V_CONNEXION,V_EXPEDITEUR_SMTP);

      -- Définition du destinataire (bris au ;)
      WHILE(V_IND_SORTIE = FALSE) LOOP
       
         -- Position du ; s'il y a lieu
         V_POS_TRAI := V_POS_INIT + INSTR(SUBSTR(V_DESTINATAIRE,V_POS_INIT+1),';');
         DBMS_OUTPUT.PUT_LINE('POS_INIT = ' || V_POS_INIT);
         DBMS_OUTPUT.PUT_LINE('POS_TRAI = ' || V_POS_TRAI);

         IF (V_POS_TRAI = V_POS_INIT) THEN
            -- Jusqu'à la fin de ligne
            UTL_SMTP.RCPT(V_CONNEXION,SUBSTR(V_DESTINATAIRE,V_POS_INIT + 1));
            V_IND_SORTIE := TRUE;
         ELSE
            -- Jusqu'au ;
            UTL_SMTP.RCPT(V_CONNEXION,SUBSTR(V_DESTINATAIRE,V_POS_INIT+1,V_POS_TRAI-1 - V_POS_INIT));
         END IF;
       
         -- Ajustement de la position de départ
         V_POS_INIT := V_POS_TRAI;

      END LOOP;
       
      -- Ouverture du flux de données
      UTL_SMTP.OPEN_DATA(V_CONNEXION);

      -- Pour permettre l'envoi de caractères spéciaux (accents)
      UTL_SMTP.WRITE_DATA(V_CONNEXION,'MIME-version: 1.0'                                  || UTL_TCP.CRLF); 
       
      -- Type MIME
      IF (A_BLB_FICHIER IS NULL) THEN
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Type: text/plain; charset=UTF-8'         || UTL_TCP.CRLF);
      ELSE
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Type: ' || MP_MI_TYPE                    || UTL_TCP.CRLF);
      END IF;

      UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Transfer-Encoding: 8bit'                    || UTL_TCP.CRLF); 
      UTL_SMTP.WRITE_DATA(V_CONNEXION,'X-Mailer: SDBM_SMTP@' || SYS_CONTEXT('USERENV','SERVER_HOST') || UTL_TCP.CRLF); 

      -- Envoi du message (entête)
      UTL_SMTP.WRITE_DATA(V_CONNEXION,'From: "'   || V_EXPEDITEUR_SMTP || '" <' || V_EXPEDITEUR_SMTP || '>' || UTL_TCP.CRLF);
      UTL_SMTP.WRITE_DATA(V_CONNEXION,'To: "'     || V_DESTINATAIRE    || '" <' || V_DESTINATAIRE    || '>' || UTL_TCP.CRLF);

      UTL_SMTP.WRITE_DATA(V_CONNEXION,'Subject: =?UTF-8?Q?' || UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.QUOTED_PRINTABLE_ENCODE(UTL_RAW.CAST_TO_RAW(A_SUJET))) || '?=' || UTL_TCP.CRLF);

      -- Ajout MIME MULTIPART (si requis)
      IF (A_BLB_FICHIER IS NOT NULL) THEN

         UTL_SMTP.WRITE_DATA(V_CONNEXION,F_BOUNDARY); 
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Type: text/plain; charset=UTF-8'         || UTL_TCP.CRLF);
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Disposition: inline; filename=""'        || UTL_TCP.CRLF);

      END IF;


      -- Envoi du message (corps du message)
      UTL_SMTP.WRITE_DATA(V_CONNEXION, UTL_TCP.CRLF);

      -- Prépration pour utilisation de WRITE_RAW_DATA directement
      V_TAMPON_MESSAGE := REPLACE(A_MESSAGE,'\n',UTL_TCP.CRLF);

      -- Découpage en morceux de 32 000 octets (limite de 32kb)
      FOR I IN 1 .. CEIL( DBMS_LOB.GETLENGTH(V_TAMPON_MESSAGE) / 32000 ) LOOP
         UTL_SMTP.WRITE_RAW_DATA(V_CONNEXION,UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(V_TAMPON_MESSAGE,32000,(I - 1) * 32000 + 1)));
      END LOOP;

      -- Fin du message (corps du message)
      UTL_SMTP.WRITE_DATA(V_CONNEXION, UTL_TCP.CRLF);


      -- Envoi du fichier (si requis)
      IF (A_BLB_FICHIER IS NOT NULL) THEN
         
         V_GROSSEUR_BLOB := DBMS_LOB.GETLENGTH(A_BLB_FICHIER);

         UTL_SMTP.WRITE_DATA(V_CONNEXION,F_BOUNDARY); 
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Type: application/octet'                                     || UTL_TCP.CRLF);
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Disposition: attachment; filename="' || A_NOM_FICHIER || '"' || UTL_TCP.CRLF);
         UTL_SMTP.WRITE_DATA(V_CONNEXION,'Content-Transfer-Encoding: base64'                                   || UTL_TCP.CRLF); 
         UTL_SMTP.WRITE_DATA(V_CONNEXION, UTL_TCP.CRLF);

         FOR I IN 1 .. CEIL( V_GROSSEUR_BLOB / MP_MI_SIZE ) LOOP
          
            IF (I = CEIL(V_GROSSEUR_BLOB / MP_MI_SIZE)) THEN
               V_GROSSEUR_MP := MOD(V_GROSSEUR_BLOB, MP_MI_SIZE);

               -- Si la taille globale est multiple de MP_MI_SIZE - correctif de ORA-21560 ou V_GROSSEUR_MP = 0
               IF (V_GROSSEUR_MP = 0) THEN
                  V_GROSSEUR_MP := MP_MI_SIZE;
               END IF;

            END IF;
      
            DBMS_LOB.READ(A_BLB_FICHIER, V_GROSSEUR_MP, (I-1) * MP_MI_SIZE + 1, V_TAMPON_MP);
            UTL_SMTP.WRITE_RAW_DATA(V_CONNEXION,UTL_ENCODE.BASE64_ENCODE(V_TAMPON_MP));

         END LOOP;

         UTL_SMTP.WRITE_DATA(V_CONNEXION, UTL_TCP.CRLF);
         UTL_SMTP.WRITE_DATA(V_CONNEXION,L_BOUNDARY); 

      END IF;

      -- Fermeture de flux de données
      UTL_SMTP.CLOSE_DATA(V_CONNEXION);
      G_TS_LAST_ERREUR := NULL;

      -- Fermeture de la connexion au serveur de courriel
      UTL_SMTP.QUIT(V_CONNEXION);

   EXCEPTION

      WHEN OTHERS THEN
         
         -- Sauvegarde du message actuel
         V_SQLERRM := SUBSTR(SQLERRM,1,512);

         -- Tentative de fermeture de session
         BEGIN
            UTL_SMTP.QUIT(V_CONNEXION);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
         
         -- Vérification pour problème générale avec SMTP (éviter un HANG sur Oracle XE)
         IF (V_SQLERRM = 'ORA-29278: SMTP transient error: 421 Service not available') THEN
            G_TS_LAST_ERREUR := SYSTIMESTAMP AT TIME ZONE 'UTC';
         END IF;
         
         -- Retour de l'erreur originale
         RAISE_APPLICATION_ERROR(-20000,'SDBM_SMTP : ' || V_SQLERRM);

   END ENVOYER_SMTP;


END SDBM_SMTP;
/
