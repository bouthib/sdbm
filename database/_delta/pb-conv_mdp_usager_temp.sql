-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY CONV_MDP_USAGER_TEMP
IS

   /******************************************************************
     FONCTION  : DESDECRYPT
     AUTEUR    : Benoit Bouthillier 2022-01-02
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de remplacer l'appel à
           DBMS_OBFUSCATION_TOOLKIT qui n'est plus disponible dans
           Oracle 21c.

     PARAMETRES:  Mot de passe encrypté  (INPUT_STRING)
                  Clé DES                (KEY_STRING)
   ******************************************************************/
   FUNCTION DESDECRYPT
   (
      INPUT_STRING  IN VARCHAR2 -- Mot de passe encrypté
     ,KEY_STRING    IN VARCHAR2 -- Clé DES
   )
   RETURN VARCHAR2
   IS

   BEGIN

      RETURN(UTL_RAW.CAST_TO_VARCHAR2(DBMS_CRYPTO.DECRYPT(UTL_RAW.CAST_TO_RAW(INPUT_STRING)
		                                         ,DBMS_CRYPTO.ENCRYPT_DES + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_NONE
		                                         ,UTL_RAW.CAST_TO_RAW(KEY_STRING)
                                                         )
                                     )
            );

   END DESDECRYPT;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP_USAGER
     AUTEUR    : Benoit Bouthillier 2009-01-05
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter le mot de passe d'un
           usager.

     PARAMETRES:  Nom de l'usager     (A_NOM_USAGER)
                  Mot de passe (ENC)  (A_MDP_ENC)
   ******************************************************************/
   FUNCTION DECRYPTER_MDP_USAGER
   (
      A_NOM_USAGER IN USAGER.NOM_USAGER%TYPE -- Nom de l'usager
     ,A_MDP_ENC    IN USAGER.MOT_PASSE%TYPE  -- Mot de passe de l'usager (ENC)
   )
   RETURN VARCHAR2
   IS
   
      -- Génération de la clé d'encryption
      V_CLE_DES VARCHAR2(16 BYTE) := RPAD(SUBSTR(A_NOM_USAGER,1,16),16,'-+4');

   BEGIN

      RETURN(TRIM(DESDECRYPT(INPUT_STRING => A_MDP_ENC, KEY_STRING => V_CLE_DES)));
   
   END DECRYPTER_MDP_USAGER;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP_CIBLE
     AUTEUR    : Benoit Bouthillier 2008-07-23
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter le mot de passe de
           la cible.

     PARAMETRES:  Nom de la cible                (A_NOM_CIBLE)
                  Mot de passe de connexion ENC  (A_MDP_USAGER)
   ******************************************************************/

   FUNCTION DECRYPTER_MDP_CIBLE
   (
      A_NOM_CIBLE   IN CIBLE.NOM_CIBLE%TYPE  -- Nom de la cible
     ,A_MDP_ENC     IN CIBLE.MDP_USAGER%TYPE -- Mot de passe de connexion (ENC)
   )
   RETURN VARCHAR2
   IS
   
      -- Génération de la clé d'encryption
      V_CLE_DES VARCHAR2(16 BYTE) := RPAD(SUBSTR(A_NOM_CIBLE,1,16),16,'+-8');

   BEGIN

      RETURN(RTRIM(DESDECRYPT(INPUT_STRING => A_MDP_ENC, KEY_STRING => V_CLE_DES)));
   
   END DECRYPTER_MDP_CIBLE;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP_SMTP
     AUTEUR    : Benoit Bouthillier 2009-01-05
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter le mot de passe
           SMTP.

     PARAMETRES:  Nom de l'usager     (A_NOM_USAGER)
                  Mot de passe (ENC)  (A_MDP_ENC)
   ******************************************************************/

   FUNCTION DECRYPTER_MDP_SMTP
   (
      A_NOM_USAGER  IN PARAMETRE.NOM_USAGER_SMTP%TYPE -- Nom de l'usager
     ,A_MDP_ENC     IN PARAMETRE.MDP_USAGER_SMTP%TYPE -- Mot de passe (ENC)
   )
   RETURN VARCHAR2
   IS
   
      -- Génération de la clé d'encryption
      V_CLE_DES VARCHAR2(16 BYTE) := RPAD(SUBSTR(A_NOM_USAGER,1,16),16,'-+8');

   BEGIN

      RETURN(RTRIM(DESDECRYPT(INPUT_STRING => A_MDP_ENC, KEY_STRING => V_CLE_DES)));
   
   END DECRYPTER_MDP_SMTP;

END CONV_MDP_USAGER_TEMP;
/

