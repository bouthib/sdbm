-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE TABLE AUDIT_APPL 
(
   DH_AUDIT     TIMESTAMP(6)         DEFAULT SYSTIMESTAMP
  ,NOM_USAGER   VARCHAR2(50 CHAR)
  ,NOM_TABLE    VARCHAR2(30 CHAR)
  ,NOM_COLONNE  VARCHAR2(30 CHAR)
  ,TYPE_DML     CHAR(1 CHAR)
  ,IDENTIFIANT  VARCHAR2(200 CHAR)
  ,ANCI_VALEUR  VARCHAR2(4000 CHAR)
  ,NOUV_VALEUR  VARCHAR2(4000 CHAR)
)
TABLESPACE SDBM_DATA;


CREATE OR REPLACE PACKAGE SDBM_AUDIT_APPL
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_AUDIT_APPL
  AUTEUR  : Benoit Bouthillier 2012-02-02
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des fonctions d'audit.

**********************************************************************/


   -- Version de l'entête PL/SQL
   VERSION_PS CONSTANT VARCHAR2(4 CHAR) := '0.01';


   PROCEDURE VERSION;

   PROCEDURE GENERER_TRIGGER
   (
      A_NOM_TABLE     VARCHAR2
     ,A_LISTE_COLONNE VARCHAR2
     ,A_EXECUTION     BOOLEAN   DEFAULT TRUE
   );

   FUNCTION VALEUR_MODIFIEE
   (
      A_ANCI_VALEUR AUDIT_APPL.ANCI_VALEUR%TYPE
     ,A_NOUV_VALEUR AUDIT_APPL.NOUV_VALEUR%TYPE
   )
   RETURN BOOLEAN;

   PROCEDURE INSERER_AUDIT
   (
      A_TYPE_DML    CHAR
     ,A_NOM_TABLE   AUDIT_APPL.NOM_TABLE%TYPE   
     ,A_NOM_COLONNE AUDIT_APPL.NOM_COLONNE%TYPE
     ,A_IDENTIFIANT AUDIT_APPL.IDENTIFIANT%TYPE
     ,A_ANCI_VALEUR AUDIT_APPL.ANCI_VALEUR%TYPE
     ,A_NOUV_VALEUR AUDIT_APPL.NOUV_VALEUR%TYPE
     ,A_USAGER      AUDIT_APPL.NOM_USAGER%TYPE  DEFAULT NVL(V('APP_USER'),USER)
   );

END SDBM_AUDIT_APPL;
/

